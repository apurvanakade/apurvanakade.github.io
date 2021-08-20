variables P Q : Prop

/--------------------------------------------------------------------------

Negation:
  ``¬ P`` is ``P → false``,
  ``¬ (¬ P)`` is ``(P → false) → false``, and so on.

Delete the ``sorry,`` below and replace them with valid proofs.
--------------------------------------------------------------------------/

theorem ex1 : P → ¬ ¬ P :=
begin
  sorry,
end

theorem contrapositive : (P → Q) → (¬Q → ¬P) :=
begin
  sorry,
end

theorem ex2 : ¬ ¬ ¬ P → ¬ P :=
begin
  sorry,
end

-- is the following provable?
theorem ex3 : ¬ ¬ P → P :=
begin
  sorry,
end