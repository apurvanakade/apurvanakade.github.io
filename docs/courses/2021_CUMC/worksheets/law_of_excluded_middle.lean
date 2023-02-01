import tactic
open_locale classical
-- tells Lean to allow the law of excluded middle

variables P Q R : Prop

/--------------------------------------------------------------------------
``push_neg``

  Simplifies negations in the target, if possible. 
  If ``hp : P`` is a hypothesis, then 
  ``push_neg at hp,`` simplyfies the negations at ``hp``, if possible.
--------------------------------------------------------------------------/

theorem ex1 : ¬ ¬ P → P := 
begin 
  push_neg,
  intro hp,
  exact hp,
end

theorem ex2 : ¬ ¬ P → P := 
begin 
  intro hp,
  push_neg at hp,
  exact hp,
end

/--------------------------------------------------------------------------
``by_contradiction``

  If the current target is ``P``,
  then ``by_contradiction hnp,`` changes the target to  ``false``
  and adds a hypothesis ``hnp : ¬P``.
--------------------------------------------------------------------------/

theorem ex3 : P ∨ ¬ P := 
begin 
  by_contradiction h,
  push_neg at h,
  cases h,
  apply h_left,
  exact h_right,
end

/--------------------------------------------------------------------------
``by_cases``

  If ``P`` is a proposition,
  then ``by_cases P,`` creates two hypothesis ``h : P`` and ``h : ¬P``.

This is the law of excluded middle.
--------------------------------------------------------------------------/

theorem ex4 : P ∨ ¬ P := 
begin 
  by_cases P,
  left, 
  exact h,
  right, 
  exact h,
end

/--------------------------------------------------------------------------
Delete the ``sorry,`` below and replace them with valid proofs.
--------------------------------------------------------------------------/

theorem de_morgan1 : ¬P ∧ ¬Q → ¬(P ∨ Q) := 
begin 
  sorry,
end

theorem de_morgan1_converse : ¬(P ∨ Q) → ¬P ∧ ¬Q := 
begin 
  sorry,
end

theorem de_morgan2 : ¬P ∨ ¬Q → ¬(P ∧ Q) := 
begin 
  sorry,
end

theorem de_morgan2_converse : ¬(P ∧ Q) → (¬P ∨ ¬Q):= 
begin 
  sorry,
end

theorem contrapositive_converse : (¬Q → ¬P) → (P → Q) :=
begin
  sorry,
end