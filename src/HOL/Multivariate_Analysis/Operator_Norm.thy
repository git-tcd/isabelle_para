(*  Title:      HOL/Multivariate_Analysis/Operator_Norm.thy
    Author:     Amine Chaieb, University of Cambridge
*)

header {* Operator Norm *}

theory Operator_Norm
imports Linear_Algebra
begin

definition "onorm f = (SUP x:{x. norm x = 1}. norm (f x))"

lemma norm_bound_generalize:
  fixes f :: "'a::euclidean_space \<Rightarrow> 'b::euclidean_space"
  assumes lf: "linear f"
  shows "(\<forall>x. norm x = 1 \<longrightarrow> norm (f x) \<le> b) \<longleftrightarrow> (\<forall>x. norm (f x) \<le> b * norm x)"
  (is "?lhs \<longleftrightarrow> ?rhs")
proof
  assume H: ?rhs
  {
    fix x :: "'a"
    assume x: "norm x = 1"
    from H[rule_format, of x] x have "norm (f x) \<le> b"
      by simp
  }
  then show ?lhs by blast
next
  assume H: ?lhs
  have bp: "b \<ge> 0"
    apply -
    apply (rule order_trans [OF norm_ge_zero])
    apply (rule H[rule_format, of "SOME x::'a. x \<in> Basis"])
    apply (auto intro: SOME_Basis norm_Basis)
    done
  {
    fix x :: "'a"
    {
      assume "x = 0"
      then have "norm (f x) \<le> b * norm x"
        by (simp add: linear_0[OF lf] bp)
    }
    moreover
    {
      assume x0: "x \<noteq> 0"
      then have n0: "norm x \<noteq> 0"
        by (metis norm_eq_zero)
      let ?c = "1/ norm x"
      have "norm (?c *\<^sub>R x) = 1"
        using x0 by (simp add: n0)
      with H have "norm (f (?c *\<^sub>R x)) \<le> b"
        by blast
      then have "?c * norm (f x) \<le> b"
        by (simp add: linear_cmul[OF lf])
      then have "norm (f x) \<le> b * norm x"
        using n0 norm_ge_zero[of x]
        by (auto simp add: field_simps)
    }
    ultimately have "norm (f x) \<le> b * norm x"
      by blast
  }
  then show ?rhs by blast
qed

lemma onorm:
  fixes f:: "'a::euclidean_space \<Rightarrow> 'b::euclidean_space"
  assumes lf: "linear f"
  shows "norm (f x) \<le> onorm f * norm x"
    and "\<forall>x. norm (f x) \<le> b * norm x \<Longrightarrow> onorm f \<le> b"
proof -
  let ?S = "(\<lambda>x. norm (f x))`{x. norm x = 1}"
  have "norm (f (SOME i. i \<in> Basis)) \<in> ?S"
    by (auto intro!: exI[of _ "SOME i. i \<in> Basis"] norm_Basis SOME_Basis)
  then have Se: "?S \<noteq> {}"
    by auto
  from linear_bounded[OF lf] have b: "bdd_above ?S"
    unfolding norm_bound_generalize[OF lf, symmetric] by auto
  then show "norm (f x) \<le> onorm f * norm x"
    apply -
    apply (rule spec[where x = x])
    unfolding norm_bound_generalize[OF lf, symmetric]
    apply (auto simp: onorm_def intro!: cSUP_upper)
    done
  show "\<forall>x. norm (f x) \<le> b * norm x \<Longrightarrow> onorm f \<le> b"
    unfolding norm_bound_generalize[OF lf, symmetric]
    using Se by (auto simp: onorm_def intro!: cSUP_least b)
qed

lemma onorm_pos_le:
  fixes f :: "'n::euclidean_space \<Rightarrow> 'm::euclidean_space"
  assumes lf: "linear f"
  shows "0 \<le> onorm f"
  using order_trans[OF norm_ge_zero onorm(1)[OF lf, of "SOME i. i \<in> Basis"]]
  by (simp add: SOME_Basis)

lemma onorm_eq_0:
  fixes f :: "'a::euclidean_space \<Rightarrow> 'b::euclidean_space"
  assumes lf: "linear f"
  shows "onorm f = 0 \<longleftrightarrow> (\<forall>x. f x = 0)"
  using onorm[OF lf]
  apply (auto simp add: onorm_pos_le)
  apply atomize
  apply (erule allE[where x="0::real"])
  using onorm_pos_le[OF lf]
  apply arith
  done

lemma onorm_const: "onorm (\<lambda>x::'a::euclidean_space. y::'b::euclidean_space) = norm y"
  using SOME_Basis by (auto simp add: onorm_def intro!: cSUP_const norm_Basis)

lemma onorm_pos_lt:
  fixes f :: "'a::euclidean_space \<Rightarrow> 'b::euclidean_space"
  assumes lf: "linear f"
  shows "0 < onorm f \<longleftrightarrow> \<not> (\<forall>x. f x = 0)"
  unfolding onorm_eq_0[OF lf, symmetric]
  using onorm_pos_le[OF lf] by arith

lemma onorm_compose:
  fixes f :: "'n::euclidean_space \<Rightarrow> 'm::euclidean_space"
    and g :: "'k::euclidean_space \<Rightarrow> 'n::euclidean_space"
  assumes lf: "linear f"
    and lg: "linear g"
  shows "onorm (f \<circ> g) \<le> onorm f * onorm g"
    apply (rule onorm(2)[OF linear_compose[OF lg lf], rule_format])
    unfolding o_def
    apply (subst mult_assoc)
    apply (rule order_trans)
    apply (rule onorm(1)[OF lf])
    apply (rule mult_left_mono)
    apply (rule onorm(1)[OF lg])
    apply (rule onorm_pos_le[OF lf])
    done

lemma onorm_neg_lemma:
  fixes f :: "'a::euclidean_space \<Rightarrow> 'b::euclidean_space"
  assumes lf: "linear f"
  shows "onorm (\<lambda>x. - f x) \<le> onorm f"
  using onorm[OF linear_compose_neg[OF lf]] onorm[OF lf]
  unfolding norm_minus_cancel by metis

lemma onorm_neg:
  fixes f :: "'a::euclidean_space \<Rightarrow> 'b::euclidean_space"
  assumes lf: "linear f"
  shows "onorm (\<lambda>x. - f x) = onorm f"
  using onorm_neg_lemma[OF lf] onorm_neg_lemma[OF linear_compose_neg[OF lf]]
  by simp

lemma onorm_triangle:
  fixes f g :: "'n::euclidean_space \<Rightarrow> 'm::euclidean_space"
  assumes lf: "linear f"
    and lg: "linear g"
  shows "onorm (\<lambda>x. f x + g x) \<le> onorm f + onorm g"
  apply(rule onorm(2)[OF linear_compose_add[OF lf lg], rule_format])
  apply (rule order_trans)
  apply (rule norm_triangle_ineq)
  apply (simp add: distrib)
  apply (rule add_mono)
  apply (rule onorm(1)[OF lf])
  apply (rule onorm(1)[OF lg])
  done

lemma onorm_triangle_le:
  fixes f :: "'n::euclidean_space \<Rightarrow> 'm::euclidean_space"
  assumes "linear f"
    and "linear g"
    and "onorm f + onorm g \<le> e"
  shows "onorm (\<lambda>x. f x + g x) \<le> e"
  apply (rule order_trans)
  apply (rule onorm_triangle)
  apply (rule assms)+
  done

lemma onorm_triangle_lt:
  fixes f g :: "'n::euclidean_space \<Rightarrow> 'm::euclidean_space"
  assumes "linear f"
    and "linear g"
    and "onorm f + onorm g < e"
  shows "onorm (\<lambda>x. f x + g x) < e"
  apply (rule order_le_less_trans)
  apply (rule onorm_triangle)
  apply (rule assms)+
  done

end
