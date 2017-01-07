/*  Title:      Tools/jEdit/src/document_model.scala
    Author:     Fabian Immler, TU Munich
    Author:     Makarius

Document model connected to jEdit buffer or external file: content of theory
node or auxiliary file (blob).
*/

package isabelle.jedit


import isabelle._

import scala.collection.mutable
import scala.util.parsing.input.CharSequenceReader

import org.gjt.sp.jedit.{jEdit, View}
import org.gjt.sp.jedit.Buffer
import org.gjt.sp.jedit.buffer.{BufferAdapter, BufferListener, JEditBuffer}


object Document_Model
{
  /* document models */

  sealed case class State(
    models: Map[Document.Node.Name, Document_Model] = Map.empty,
    buffer_models: Map[JEditBuffer, Buffer_Model] = Map.empty)
  {
    def models_iterator: Iterator[Document_Model] =
      for ((_, model) <- models.iterator) yield model

    def file_models_iterator: Iterator[File_Model] =
      for {
        (_, model) <- models.iterator
        if model.isInstanceOf[File_Model]
      } yield model.asInstanceOf[File_Model]

    def buffer_models_iterator: Iterator[Buffer_Model] =
      for ((_, model) <- buffer_models.iterator) yield model


    def open_buffer(session: Session, node_name: Document.Node.Name, buffer: Buffer)
      : (Buffer_Model, State) =
    {
      val old_model =
        models.get(node_name) match {
          case Some(file_model: File_Model) => Some(file_model)
          case Some(buffer_model: Buffer_Model) => Some(buffer_model.exit())
          case _ => None
        }
      val buffer_model = Buffer_Model(session, node_name, buffer).init(old_model)
      (buffer_model,
        copy(models = models + (node_name -> buffer_model),
          buffer_models = buffer_models + (buffer -> buffer_model)))
    }

    def close_buffer(buffer: JEditBuffer): State =
    {
      buffer_models.get(buffer) match {
        case None => this
        case Some(buffer_model) =>
          val file_model = buffer_model.exit()
          copy(models = models + (file_model.node_name -> file_model),
            buffer_models = buffer_models - buffer)
      }
    }
  }

  private val state = Synchronized(State())  // owned by GUI thread

  def get(name: Document.Node.Name): Option[Document_Model] =
    state.value.models.get(name)

  def get(buffer: JEditBuffer): Option[Buffer_Model] =
    state.value.buffer_models.get(buffer)

  def is_stable(): Boolean =
    state.value.models_iterator.forall(_.is_stable)


  /* init and exit */

  def init(session: Session, node_name: Document.Node.Name, buffer: Buffer): Buffer_Model =
  {
    GUI_Thread.require {}
    state.change_result(st =>
      st.buffer_models.get(buffer) match {
        case Some(buffer_model) if buffer_model.node_name == node_name =>
          buffer_model.init_token_marker
          (buffer_model, st)
        case _ =>
          val res = st.close_buffer(buffer).open_buffer(session, node_name, buffer)
          buffer.propertiesChanged
          res
      })
  }

  def exit(buffer: Buffer)
  {
    GUI_Thread.require {}
    state.change(st =>
      if (st.buffer_models.isDefinedAt(buffer)) {
        val res = st.close_buffer(buffer)
        buffer.propertiesChanged
        res
      }
      else st)
  }


  /* required nodes */

  def required_nodes(): Set[Document.Node.Name] =
    (for {
      model <- state.value.models_iterator
      if model.node_required
    } yield model.node_name).toSet

  def node_required(name: Document.Node.Name, toggle: Boolean = false, set: Boolean = false)
  {
    GUI_Thread.require {}

    val changed =
      state.change_result(st =>
        st.models.get(name) match {
          case None => (false, st)
          case Some(model) =>
            val required = if (toggle) !model.node_required else set
            model match {
              case model1: File_Model if required != model1.node_required =>
                (true, st.copy(models = st.models + (name -> model1.copy(node_required = required))))
              case model1: Buffer_Model if required != model1.node_required =>
                model1.set_node_required(required); (true, st)
              case _ => (false, st)
            }
        })
    if (changed) {
      PIDE.options_changed()
      PIDE.editor.flush()
    }
  }

  def view_node_required(view: View, toggle: Boolean = false, set: Boolean = false): Unit =
    Document_Model.get(view.getBuffer).foreach(model =>
      node_required(model.node_name, toggle = toggle, set = set))


  /* flushed edits */

  def flush_edits(hidden: Boolean): (Document.Blobs, List[Document.Edit_Text]) =
  {
    GUI_Thread.require {}

    state.change_result(st =>
      {
        val doc_blobs =
          Document.Blobs(
            (for {
              model <- st.models_iterator
              blob <- model.get_blob
            } yield (model.node_name -> blob)).toMap)

        val buffer_edits =
          (for {
            model <- st.buffer_models_iterator
            edit <- model.flush_edits(doc_blobs, hidden).iterator
          } yield edit).toList

        val file_edits =
          (for {
            model <- st.file_models_iterator
            change <- model.flush_edits(doc_blobs, hidden)
          } yield change).toList

        val edits = buffer_edits ::: file_edits.flatMap(_._1)

        ((doc_blobs, edits),
          st.copy(
            models = (st.models /: file_edits) { case (ms, (_, m)) => ms + (m.node_name -> m) }))
      })
  }


  /* file content */

  sealed case class File_Content(text: String)
  {
    lazy val bytes: Bytes = Bytes(text)
    lazy val chunk: Symbol.Text_Chunk = Symbol.Text_Chunk(text)
    lazy val bibtex_entries: List[(String, Text.Offset)] = Bibtex_JEdit.parse_entries(text)
  }
}

trait Document_Model extends Document.Model
{
  /* content */

  def bibtex_entries: List[(String, Text.Offset)]


  /* perspective */

  def document_view_ranges(snapshot: Document.Snapshot): List[Text.Range] = Nil

  def node_perspective(
    doc_blobs: Document.Blobs, hidden: Boolean): (Boolean, Document.Node.Perspective_Text) =
  {
    GUI_Thread.require {}

    if (Isabelle.continuous_checking && is_theory) {
      val snapshot = this.snapshot()

      val reparse = snapshot.node.load_commands_changed(doc_blobs)
      val perspective =
        if (hidden) Text.Perspective.empty
        else {
          val view_ranges = document_view_ranges(snapshot)
          val load_ranges = snapshot.commands_loading_ranges(PIDE.editor.visible_node(_))
          Text.Perspective(view_ranges ::: load_ranges)
        }
      val overlays = PIDE.editor.node_overlays(node_name)

      (reparse, Document.Node.Perspective(node_required, perspective, overlays))
    }
    else (false, Document.Node.no_perspective_text)
  }
}

case class File_Model(
  session: Session,
  node_name: Document.Node.Name,
  content: Document_Model.File_Content,
  node_required: Boolean = false,
  last_perspective: Document.Node.Perspective_Text = Document.Node.no_perspective_text,
  pending_edits: List[Text.Edit] = Nil) extends Document_Model
{
  /* header */

  // FIXME eliminate clone
  def node_header: Document.Node.Header =
    PIDE.resources.special_header(node_name) getOrElse
    {
      if (is_theory)
        PIDE.resources.check_thy_reader(
          "", node_name, new CharSequenceReader(content.text), Token.Pos.command)
      else Document.Node.no_header
    }


  /* content */

  def get_blob: Option[Document.Blob] =
    if (is_theory) None
    else Some(Document.Blob(content.bytes, content.chunk, pending_edits.nonEmpty))

  def bibtex_entries: List[(String, Text.Offset)] =
    if (Bibtex_JEdit.check(node_name)) content.bibtex_entries else Nil


  /* edits */

  def update_text(text: String): Option[File_Model] =
    Text.Edit.replace(0, content.text, text) match {
      case Nil => None
      case edits =>
        val content1 = Document_Model.File_Content(text)
        val pending_edits1 = pending_edits ::: edits
        Some(copy(content = content1, pending_edits = pending_edits1))
    }

  def flush_edits(doc_blobs: Document.Blobs, hidden: Boolean)
    : Option[(List[Document.Edit_Text], File_Model)] =
  {
    val (reparse, perspective) = node_perspective(doc_blobs, hidden)
    if (reparse || pending_edits.nonEmpty || last_perspective != perspective) {
      // FIXME eliminate clone
      val edits: List[Document.Edit_Text] =
        get_blob match {
          case None =>
            List(session.header_edit(node_name, node_header),
              node_name -> Document.Node.Edits(pending_edits),
              node_name -> perspective)
          case Some(blob) =>
            List(node_name -> Document.Node.Blob(blob),
              node_name -> Document.Node.Edits(pending_edits))
        }
      Some((edits, copy(last_perspective = perspective, pending_edits = Nil)))
    }
    else None
  }


  /* snapshot */

  def is_stable: Boolean = pending_edits.isEmpty
  def snapshot(): Document.Snapshot = session.snapshot(node_name, pending_edits)
}

case class Buffer_Model(session: Session, node_name: Document.Node.Name, buffer: Buffer)
  extends Document_Model
{
  /* header */

  def node_header(): Document.Node.Header =
  {
    GUI_Thread.require {}

    // FIXME eliminate clone
    PIDE.resources.special_header(node_name) getOrElse
    {
      if (is_theory) {
        JEdit_Lib.buffer_lock(buffer) {
          Token_Markup.line_token_iterator(
            Thy_Header.bootstrap_syntax, buffer, 0, buffer.getLineCount).collectFirst(
              {
                case Text.Info(range, tok) if tok.is_command(Thy_Header.THEORY) => range.start
              })
            match {
              case Some(offset) =>
                val length = buffer.getLength - offset
                PIDE.resources.check_thy_reader("", node_name,
                  new CharSequenceReader(buffer.getSegment(offset, length)), Token.Pos.command)
              case None =>
                Document.Node.no_header
            }
        }
      }
      else Document.Node.no_header
    }
  }


  /* perspective */

  // owned by GUI thread
  private var _node_required = false
  def node_required: Boolean = _node_required
  def set_node_required(b: Boolean) { GUI_Thread.require { _node_required = b } }

  override def document_view_ranges(snapshot: Document.Snapshot): List[Text.Range] =
  {
    GUI_Thread.require {}

    (for {
      doc_view <- PIDE.document_views(buffer).iterator
      range <- doc_view.perspective(snapshot).ranges.iterator
    } yield range).toList
  }


  /* blob */

  private var _blob: Option[(Bytes, Symbol.Text_Chunk)] = None  // owned by GUI thread

  private def reset_blob(): Unit = GUI_Thread.require { _blob = None }

  def get_blob: Option[Document.Blob] =
    GUI_Thread.require {
      if (is_theory) None
      else {
        val (bytes, chunk) =
          _blob match {
            case Some(x) => x
            case None =>
              val bytes = PIDE.resources.file_content(buffer)
              val chunk = Symbol.Text_Chunk(buffer.getSegment(0, buffer.getLength))
              _blob = Some((bytes, chunk))
              (bytes, chunk)
          }
        val changed = pending_edits.nonEmpty
        Some(Document.Blob(bytes, chunk, changed))
      }
    }


  /* bibtex entries */

  private var _bibtex_entries: Option[List[(String, Text.Offset)]] = None  // owned by GUI thread

  private def reset_bibtex_entries(): Unit = GUI_Thread.require { _bibtex_entries = None }

  def bibtex_entries: List[(String, Text.Offset)] =
    GUI_Thread.require {
      if (Bibtex_JEdit.check(buffer)) {
        _bibtex_entries match {
          case Some(entries) => entries
          case None =>
            val text = JEdit_Lib.buffer_text(buffer)
            val entries = Bibtex_JEdit.parse_entries(text)
            _bibtex_entries = Some(entries)
            entries
        }
      }
      else Nil
    }


  /* edits */

  def node_edits(text_edits: List[Text.Edit], perspective: Document.Node.Perspective_Text)
    : List[Document.Edit_Text] =
  {
    val edits: List[Document.Edit_Text] =
      get_blob match {
        case None =>
          List(session.header_edit(node_name, node_header()),
            node_name -> Document.Node.Edits(text_edits),
            node_name -> perspective)
        case Some(blob) =>
          List(node_name -> Document.Node.Blob(blob),
            node_name -> Document.Node.Edits(text_edits))
      }
    edits.filterNot(_._2.is_void)
  }


  /* pending edits */

  private object pending_edits
  {
    private val pending = new mutable.ListBuffer[Text.Edit]
    private var last_perspective = Document.Node.no_perspective_text

    def nonEmpty: Boolean = synchronized { pending.nonEmpty }
    def get_edits: List[Text.Edit] = synchronized { pending.toList }
    def get_last_perspective: Document.Node.Perspective_Text = synchronized { last_perspective }
    def set_last_perspective(perspective: Document.Node.Perspective_Text): Unit =
      synchronized { last_perspective = perspective }

    def flush_edits(doc_blobs: Document.Blobs, hidden: Boolean): List[Document.Edit_Text] =
      synchronized {
        GUI_Thread.require {}

        val edits = get_edits
        val (reparse, perspective) = node_perspective(doc_blobs, hidden)
        if (reparse || edits.nonEmpty || last_perspective != perspective) {
          pending.clear
          last_perspective = perspective
          node_edits(edits, perspective)
        }
        else Nil
      }

    def edit(edits: List[Text.Edit]): Unit = synchronized
    {
      GUI_Thread.require {}

      reset_blob()
      reset_bibtex_entries()

      for (doc_view <- PIDE.document_views(buffer))
        doc_view.rich_text_area.active_reset()

      pending ++= edits
      PIDE.editor.invoke()
    }
  }

  def is_stable(): Boolean = !pending_edits.nonEmpty
  def snapshot(): Document.Snapshot = session.snapshot(node_name, pending_edits.get_edits)

  def flush_edits(doc_blobs: Document.Blobs, hidden: Boolean): List[Document.Edit_Text] =
    pending_edits.flush_edits(doc_blobs, hidden)


  /* buffer listener */

  private val buffer_listener: BufferListener = new BufferAdapter
  {
    override def contentInserted(buffer: JEditBuffer,
      start_line: Int, offset: Int, num_lines: Int, length: Int)
    {
      pending_edits.edit(List(Text.Edit.insert(offset, buffer.getText(offset, length))))
    }

    override def preContentRemoved(buffer: JEditBuffer,
      start_line: Int, offset: Int, num_lines: Int, removed_length: Int)
    {
      pending_edits.edit(List(Text.Edit.remove(offset, buffer.getText(offset, removed_length))))
    }
  }


  /* syntax */

  def syntax_changed()
  {
    JEdit_Lib.buffer_line_manager(buffer).setFirstInvalidLineContext(0)
    for (text_area <- JEdit_Lib.jedit_text_areas(buffer))
      Untyped.method(Class.forName("org.gjt.sp.jedit.textarea.TextArea"), "foldStructureChanged").
        invoke(text_area)
    buffer.invalidateCachedFoldLevels
  }

  def init_token_marker()
  {
    Isabelle.buffer_token_marker(buffer) match {
      case Some(marker) if marker != buffer.getTokenMarker =>
        buffer.setTokenMarker(marker)
        syntax_changed()
      case _ =>
    }
  }


  /* init */

  def init(old_model: Option[File_Model]): Buffer_Model =
  {
    GUI_Thread.require {}

    old_model match {
      case None =>
        pending_edits.edit(List(Text.Edit.insert(0, JEdit_Lib.buffer_text(buffer))))
      case Some(file_model) =>
        set_node_required(file_model.node_required)
        pending_edits.set_last_perspective(file_model.last_perspective)
        pending_edits.edit(
          file_model.pending_edits :::
            Text.Edit.replace(0, file_model.content.text, JEdit_Lib.buffer_text(buffer)))
    }

    buffer.addBufferListener(buffer_listener)
    init_token_marker()

    this
  }


  /* exit */

  def exit(): File_Model =
  {
    GUI_Thread.require {}

    buffer.removeBufferListener(buffer_listener)
    init_token_marker()

    val content = Document_Model.File_Content(JEdit_Lib.buffer_text(buffer))
    File_Model(session, node_name, content, node_required,
      pending_edits.get_last_perspective, pending_edits.get_edits)
  }
}
