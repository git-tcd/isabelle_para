(*<*)theory WFrec = Main:(*>*)

text{*\noindent
So far, all recursive definitions where shown to terminate via measure
functions. Sometimes this can be quite inconvenient or even
impossible. Fortunately, \isacommand{recdef} supports much more
general definitions. For example, termination of Ackermann's function
can be shown by means of the lexicographic product @{text"<*lex*>"}:
*}

consts ack :: "nat\<times>nat \<Rightarrow> nat";
recdef ack "measure(\<lambda>m. m) <*lex*> measure(\<lambda>n. n)"
  "ack(0,n)         = Suc n"
  "ack(Suc m,0)     = ack(m, 1)"
  "ack(Suc m,Suc n) = ack(m,ack(Suc m,n))";

text{*\noindent
The lexicographic product decreases if either its first component
decreases (as in the second equation and in the outer call in the
third equation) or its first component stays the same and the second
component decreases (as in the inner call in the third equation).

In general, \isacommand{recdef} supports termination proofs based on
arbitrary \emph{wellfounded relations}, i.e.\ \emph{wellfounded
recursion}\indexbold{recursion!wellfounded}\index{wellfounded
recursion|see{recursion, wellfounded}}.  A relation $<$ is
\bfindex{wellfounded} if it has no infinite descending chain $\cdots <
a@2 < a@1 < a@0$. Clearly, a function definition is total iff the set
of all pairs $(r,l)$, where $l$ is the argument on the left-hand side of an equation
and $r$ the argument of some recursive call on the corresponding
right-hand side, induces a wellfounded relation.  For a systematic
account of termination proofs via wellfounded relations see, for
example, \cite{Baader-Nipkow}.

Each \isacommand{recdef} definition should be accompanied (after the
name of the function) by a wellfounded relation on the argument type
of the function. For example, @{term measure} is defined by
@{prop[display]"measure(f::'a \<Rightarrow> nat) \<equiv> {(y,x). f y < f x}"}
and it has been proved that @{term"measure f"} is always wellfounded.

In addition to @{term measure}, the library provides
a number of further constructions for obtaining wellfounded relations.

wf proof auto if stndard constructions.
*}
(*<*)end(*>*)