variables P Q R : Prop

/--------------------------------------------------------------------------
``cases``

  ``cases`` is a tactic that breaks up complicated terms.
  If ``hpq`` is a proof of ``P ∧ Q`` or ``P ∨ Q``, then use
  ``cases hpq,``.

English translation:
If ``P ∧ Q`` is true then both ``P`` and ``Q`` are true.
If ``P ∨ Q`` is true then either ``P`` or ``Q`` is true.
--------------------------------------------------------------------------/

theorem ex1 : P ∧ Q → P :=
begin
  intro hpq, 
  cases hpq, 
  exact hpq_left,
end

theorem ex2 : P ∨ P → P :=
begin
  intro hpp,
  cases hpp,
  exact hpp,
  exact hpp,
end

/--------------------------------------------------------------------------
``split``

  If the current target is ``P ∧ Q`` then use
  ``split,``.

English translation:
To prove ``P ∧ Q`` we need to prove ``P`` and ``Q`` separately.
--------------------------------------------------------------------------/

theorem ex3 (hp : P) (hq : Q) : P ∧ Q :=
begin 
  split,
  exact hp,
  exact hq,
end

/--------------------------------------------------------------------------
``left``/``right``

  If the current target is ``P ∨ Q``, then use
  either ``left,`` or ``right,`` (choose wisely).

English translation:
To prove ``P ∨ Q`` we need to prove either ``P`` (left) or ``Q`` (right).
--------------------------------------------------------------------------/

theorem ex4 : P → (P ∨ Q) :=
begin
  intro hp,
  left,
  exact hp,
end

/--------------------------------------------------------------------------
Delete the ``sorry,`` below and replace them with valid proofs.
Don't forget the ``,`` at the end of each tactic.
--------------------------------------------------------------------------/

theorem comm_and : P ∧ Q → Q ∧ P :=
begin
  sorry,
end 

-- Be careful: the order of tactics matters, just like in math!
theorem comm_or : P ∨ Q → Q ∨ P :=
begin
  sorry,
end

theorem currying : (P ∧ Q → R) → (P → (Q → R)) := 
begin 
  sorry,
end

theorem or_implies : ((P ∨ Q) → R) → (P → R) ∧ (Q → R) := 
begin
  sorry,
end

theorem or_implies_converse : (P → R) ∧ (Q → R) → ((P ∨ Q) → R):= 
begin
  sorry,
end

-- you can also use ``apply`` for a sequence of implications ``P → Q → R``
-- if the target is ``R``.
theorem uncurrying : (P → (Q → R)) → (P ∧ Q → R) := 
begin 
  sorry,
end
