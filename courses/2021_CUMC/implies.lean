variables P Q R S T U : Prop

/--------------------------------------------------------------------------
``exact``

  If ``P`` is the current target and
  ``hp`` is a proof of ``P``, then
  ``exact hp,`` closes the goal.

English translation: 
This is exactly what we wanted to prove.
--------------------------------------------------------------------------/

theorem tautology (hp : P) : P :=
begin
  exact hp,
end

/--------------------------------------------------------------------------
``intro``

  If the current target is an implication ``P → Q``, then
  ``intro hp,`` will produce a hypothesis
  ``hp : P`` and changes the target to  ``Q``.

English translation: 
To prove ``P → Q``, let us assume ``P`` and try to prove ``Q``.
--------------------------------------------------------------------------/

theorem tautology' : P → P :=
begin
  intro hp,
  exact hp,
end

/--------------------------------------------------------------------------
``apply``

  If the current target is ``Q`` and
  ``h`` is a proof of ``P → Q``, then
  ``apply h,`` changes target to ``P``.

English translation:
(Backward reasoning.)
To prove ``Q``, since we know ``P → Q``, it suffices to prove ``P``.
--------------------------------------------------------------------------/

theorem syllogism (hp : P) (h : P → Q) : Q :=
begin
  apply h, 
  exact hp,
end

/--------------------------------------------------------------------------

Delete the ``sorry,`` below and replace them with valid proofs.
Don't forget the ``,`` at the end of each line.

--------------------------------------------------------------------------/

theorem ex1 (P Q R : Prop) (f : P → Q) (g : Q → R) : P → R :=
begin
  sorry,
end

-- In Lean, implications are "right associative",
-- which means that ``P → Q → R`` is the same as ``P → (Q → R).``
theorem ex2 (P Q : Prop): P → (Q → P) :=
begin
  sorry,
end

theorem ex3 (P Q : Prop) : ((Q → P) → (Q → P)) :=
begin
  sorry,
end

theorem ex7 
  (hpq : P → Q)
  (hqr : Q → R)
  (hqt : Q → T)
  (hst : S → T)
  (htu : T → U)
  : P → U :=
begin
  sorry,
end

-- Implication is not associative
-- what happens if you try to prove the following?
theorem ex2' (P Q : Prop): (P → Q) → P :=
begin
  sorry,
end