(* ========================================================================= *)
(* Isabelle ML SPECIFIC FUNCTIONS                                            *)
(* ========================================================================= *)

structure Portable :> Portable =
struct

(* ------------------------------------------------------------------------- *)
(* The ML implementation.                                                    *)
(* ------------------------------------------------------------------------- *)

val ml = ml_system;

(* ------------------------------------------------------------------------- *)
(* Pointer equality using the run-time system.                               *)
(* ------------------------------------------------------------------------- *)

val pointerEqual = pointer_eq;

(* ------------------------------------------------------------------------- *)
(* Timing function applications a la Mosml.time.                             *)
(* ------------------------------------------------------------------------- *)

val time = timeap;

(* ------------------------------------------------------------------------- *)
(* Critical section markup (multiprocessing)                                 *)
(* ------------------------------------------------------------------------- *)

fun CRITICAL e = NAMED_CRITICAL "metis" e;

(* ------------------------------------------------------------------------- *)
(* Generating random values.                                                 *)
(* ------------------------------------------------------------------------- *)

val randomWord = RandomWord.next;
val randomBool = RandomWord.next_bit;
fun randomInt n = Word.toInt (Word.mod (randomWord (), Word.fromInt n));

val real_word = real o Word.toInt;
val normalizer = 1.0 / real_word RandomWord.range;
fun randomReal () = real_word (RandomWord.next ()) * normalizer;

end

(* ------------------------------------------------------------------------- *)
(* Quotations a la Moscow ML.                                                *)
(* ------------------------------------------------------------------------- *)

datatype 'a frag = QUOTE of string | ANTIQUOTE of 'a;
