(*  Title:      HOL/Nitpick_Examples/Mono_Nits.thy
    Author:     Jasmin Blanchette, TU Muenchen
    Copyright   2009-2011

Examples featuring Nitpick's monotonicity check.
*)

section \<open>Examples Featuring Nitpick's Monotonicity Check\<close>

theory Mono_Nits
imports Main
        (* "~/afp/thys/DPT-SAT-Solver/DPT_SAT_Solver" *)
        (* "~/afp/thys/AVL-Trees/AVL2" "~/afp/thys/Huffman/Huffman" *)
begin

ML \<open>
open Nitpick_Util
open Nitpick_HOL
open Nitpick_Preproc

exception BUG

val thy = @{theory}
val ctxt = @{context}
val subst = []
val tac_timeout = seconds 1.0
val case_names = case_const_names ctxt
val defs = all_defs_of thy subst
val nondefs = all_nondefs_of ctxt subst
val def_tables = const_def_tables ctxt subst defs
val nondef_table = const_nondef_table nondefs
val simp_table = Unsynchronized.ref (const_simp_table ctxt subst)
val psimp_table = const_psimp_table ctxt subst
val choice_spec_table = const_choice_spec_table ctxt subst
val intro_table = inductive_intro_table ctxt subst def_tables
val ground_thm_table = ground_theorem_table thy
val ersatz_table = ersatz_table ctxt
val hol_ctxt as {thy, ...} : hol_context =
  {thy = thy, ctxt = ctxt, max_bisim_depth = ~1, boxes = [], wfs = [],
   user_axioms = NONE, debug = false, whacks = [], binary_ints = SOME false,
   destroy_constrs = true, specialize = false, star_linear_preds = false,
   total_consts = NONE, needs = NONE, tac_timeout = tac_timeout, evals = [],
   case_names = case_names, def_tables = def_tables,
   nondef_table = nondef_table, nondefs = nondefs, simp_table = simp_table,
   psimp_table = psimp_table, choice_spec_table = choice_spec_table,
   intro_table = intro_table, ground_thm_table = ground_thm_table,
   ersatz_table = ersatz_table, skolems = Unsynchronized.ref [],
   special_funs = Unsynchronized.ref [], unrolled_preds = Unsynchronized.ref [],
   wf_cache = Unsynchronized.ref [], constr_cache = Unsynchronized.ref []}
val binarize = false

fun is_mono t =
  Nitpick_Mono.formulas_monotonic hol_ctxt binarize @{typ 'a} ([t], [])

fun is_const t =
  let val T = fastype_of t in
    Logic.mk_implies (Logic.mk_equals (Free ("dummyP", T), t), @{const False})
    |> is_mono
  end

fun mono t = is_mono t orelse raise BUG
fun nonmono t = not (is_mono t) orelse raise BUG
fun const t = is_const t orelse raise BUG
fun nonconst t = not (is_const t) orelse raise BUG
\<close>

ML \<open>Nitpick_Mono.trace := false\<close>

ML_val \<open>const @{term "A::('a\<Rightarrow>'b)"}\<close>
ML_val \<open>const @{term "(A::'a set) = A"}\<close>
ML_val \<open>const @{term "(A::'a set set) = A"}\<close>
ML_val \<open>const @{term "(\<lambda>x::'a set. a \<in> x)"}\<close>
ML_val \<open>const @{term "{{a::'a}} = C"}\<close>
ML_val \<open>const @{term "{f::'a\<Rightarrow>nat} = {g::'a\<Rightarrow>nat}"}\<close>
ML_val \<open>const @{term "A \<union> (B::'a set)"}\<close>
ML_val \<open>const @{term "\<lambda>A B x::'a. A x \<or> B x"}\<close>
ML_val \<open>const @{term "P (a::'a)"}\<close>
ML_val \<open>const @{term "\<lambda>a::'a. b (c (d::'a)) (e::'a) (f::'a)"}\<close>
ML_val \<open>const @{term "\<forall>A::'a set. a \<in> A"}\<close>
ML_val \<open>const @{term "\<forall>A::'a set. P A"}\<close>
ML_val \<open>const @{term "P \<or> Q"}\<close>
ML_val \<open>const @{term "A \<union> B = (C::'a set)"}\<close>
ML_val \<open>const @{term "(\<lambda>A B x::'a. A x \<or> B x) A B = C"}\<close>
ML_val \<open>const @{term "(if P then (A::'a set) else B) = C"}\<close>
ML_val \<open>const @{term "let A = (C::'a set) in A \<union> B"}\<close>
ML_val \<open>const @{term "THE x::'b. P x"}\<close>
ML_val \<open>const @{term "(\<lambda>x::'a. False)"}\<close>
ML_val \<open>const @{term "(\<lambda>x::'a. True)"}\<close>
ML_val \<open>const @{term "(\<lambda>x::'a. False) = (\<lambda>x::'a. False)"}\<close>
ML_val \<open>const @{term "(\<lambda>x::'a. True) = (\<lambda>x::'a. True)"}\<close>
ML_val \<open>const @{term "Let (a::'a) A"}\<close>
ML_val \<open>const @{term "A (a::'a)"}\<close>
ML_val \<open>const @{term "insert (a::'a) A = B"}\<close>
ML_val \<open>const @{term "- (A::'a set)"}\<close>
ML_val \<open>const @{term "finite (A::'a set)"}\<close>
ML_val \<open>const @{term "\<not> finite (A::'a set)"}\<close>
ML_val \<open>const @{term "finite (A::'a set set)"}\<close>
ML_val \<open>const @{term "\<lambda>a::'a. A a \<and> \<not> B a"}\<close>
ML_val \<open>const @{term "A < (B::'a set)"}\<close>
ML_val \<open>const @{term "A \<le> (B::'a set)"}\<close>
ML_val \<open>const @{term "[a::'a]"}\<close>
ML_val \<open>const @{term "[a::'a set]"}\<close>
ML_val \<open>const @{term "[A \<union> (B::'a set)]"}\<close>
ML_val \<open>const @{term "[A \<union> (B::'a set)] = [C]"}\<close>
ML_val \<open>const @{term "{(\<lambda>x::'a. x = a)} = C"}\<close>
ML_val \<open>const @{term "(\<lambda>a::'a. \<not> A a) = B"}\<close>
ML_val \<open>const @{prop "\<forall>F f g (h::'a set). F f \<and> F g \<and> \<not> f a \<and> g a \<longrightarrow> \<not> f a"}\<close>
ML_val \<open>const @{term "\<lambda>A B x::'a. A x \<and> B x \<and> A = B"}\<close>
ML_val \<open>const @{term "p = (\<lambda>(x::'a) (y::'a). P x \<or> \<not> Q y)"}\<close>
ML_val \<open>const @{term "p = (\<lambda>(x::'a) (y::'a). p x y :: bool)"}\<close>
ML_val \<open>const @{term "p = (\<lambda>A B x. A x \<and> \<not> B x) (\<lambda>x. True) (\<lambda>y. x \<noteq> y)"}\<close>
ML_val \<open>const @{term "p = (\<lambda>y. x \<noteq> y)"}\<close>
ML_val \<open>const @{term "(\<lambda>x. (p::'a\<Rightarrow>bool\<Rightarrow>bool) x False)"}\<close>
ML_val \<open>const @{term "(\<lambda>x y. (p::'a\<Rightarrow>'a\<Rightarrow>bool\<Rightarrow>bool) x y False)"}\<close>
ML_val \<open>const @{term "f = (\<lambda>x::'a. P x \<longrightarrow> Q x)"}\<close>
ML_val \<open>const @{term "\<forall>a::'a. P a"}\<close>

ML_val \<open>nonconst @{term "\<forall>P (a::'a). P a"}\<close>
ML_val \<open>nonconst @{term "THE x::'a. P x"}\<close>
ML_val \<open>nonconst @{term "SOME x::'a. P x"}\<close>
ML_val \<open>nonconst @{term "(\<lambda>A B x::'a. A x \<or> B x) = myunion"}\<close>
ML_val \<open>nonconst @{term "(\<lambda>x::'a. False) = (\<lambda>x::'a. True)"}\<close>
ML_val \<open>nonconst @{prop "\<forall>F f g (h::'a set). F f \<and> F g \<and> \<not> a \<in> f \<and> a \<in> g \<longrightarrow> F h"}\<close>

ML_val \<open>mono @{prop "Q (\<forall>x::'a set. P x)"}\<close>
ML_val \<open>mono @{prop "P (a::'a)"}\<close>
ML_val \<open>mono @{prop "{a} = {b::'a}"}\<close>
ML_val \<open>mono @{prop "(\<lambda>x. x = a) = (\<lambda>y. y = (b::'a))"}\<close>
ML_val \<open>mono @{prop "(a::'a) \<in> P \<and> P \<union> P = P"}\<close>
ML_val \<open>mono @{prop "\<forall>F::'a set set. P"}\<close>
ML_val \<open>mono @{prop "\<not> (\<forall>F f g (h::'a set). F f \<and> F g \<and> \<not> a \<in> f \<and> a \<in> g \<longrightarrow> F h)"}\<close>
ML_val \<open>mono @{prop "\<not> Q (\<forall>x::'a set. P x)"}\<close>
ML_val \<open>mono @{prop "\<not> (\<forall>x::'a. P x)"}\<close>
ML_val \<open>mono @{prop "myall P = (P = (\<lambda>x::'a. True))"}\<close>
ML_val \<open>mono @{prop "myall P = (P = (\<lambda>x::'a. False))"}\<close>
ML_val \<open>mono @{prop "\<forall>x::'a. P x"}\<close>
ML_val \<open>mono @{term "(\<lambda>A B x::'a. A x \<or> B x) \<noteq> myunion"}\<close>

ML_val \<open>nonmono @{prop "A = (\<lambda>x::'a. True) \<and> A = (\<lambda>x. False)"}\<close>
ML_val \<open>nonmono @{prop "\<forall>F f g (h::'a set). F f \<and> F g \<and> \<not> a \<in> f \<and> a \<in> g \<longrightarrow> F h"}\<close>

ML \<open>
val preproc_timeout = seconds 5.0
val mono_timeout = seconds 1.0

fun is_forbidden_theorem name =
  length (Long_Name.explode name) <> 2 orelse
  String.isPrefix "type_definition" (List.last (Long_Name.explode name)) orelse
  String.isPrefix "arity_" (List.last (Long_Name.explode name)) orelse
  String.isSuffix "_def" name orelse
  String.isSuffix "_raw" name

fun theorems_of thy =
  filter (fn (name, th) =>
             not (is_forbidden_theorem name) andalso
             Thm.theory_name th = Context.theory_name thy)
         (Global_Theory.all_thms_of thy true)

fun check_formulas tsp =
  let
    fun is_type_actually_monotonic T =
      Nitpick_Mono.formulas_monotonic hol_ctxt binarize T tsp
    val free_Ts = fold Term.add_tfrees ((@) tsp) [] |> map TFree
    val (mono_free_Ts, nonmono_free_Ts) =
      Timeout.apply mono_timeout
          (List.partition is_type_actually_monotonic) free_Ts
  in
    if not (null mono_free_Ts) then "MONO"
    else if not (null nonmono_free_Ts) then "NONMONO"
    else "NIX"
  end
  handle Timeout.TIMEOUT _ => "TIMEOUT"
       | NOT_SUPPORTED _ => "UNSUP"
       | exn => if Exn.is_interrupt exn then Exn.reraise exn else "UNKNOWN"

fun check_theory thy =
  let
    val path = File.tmp_path (Context.theory_name thy ^ ".out" |> Path.explode)
    val _ = File.write path ""
    fun check_theorem (name, th) =
      let
        val t = th |> Thm.prop_of |> Type.legacy_freeze |> close_form
        val neg_t = Logic.mk_implies (t, @{prop False})
        val (nondef_ts, def_ts, _, _, _, _) =
          Timeout.apply preproc_timeout (preprocess_formulas hol_ctxt [])
                              neg_t
        val res = name ^ ": " ^ check_formulas (nondef_ts, def_ts)
      in File.append path (res ^ "\n"); writeln res end
      handle Timeout.TIMEOUT _ => ()
  in thy |> theorems_of |> List.app check_theorem end
\<close>

(*
ML_val {* check_theory @{theory AVL2} *}
ML_val {* check_theory @{theory Fun} *}
ML_val {* check_theory @{theory Huffman} *}
ML_val {* check_theory @{theory List} *}
ML_val {* check_theory @{theory Map} *}
ML_val {* check_theory @{theory Relation} *}
*)

ML \<open>getenv "ISABELLE_TMP"\<close>

end
