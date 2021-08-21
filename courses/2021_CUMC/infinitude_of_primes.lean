import data.nat.prime 
open nat

theorem infinitude_of_primes (n : ℕ) : ∃ (p : ℕ), prime p ∧ n ≤ p :=
-- For every natural number n, 
-- there exists a number p, such that 
-- n is less than or equal to p and p is prime

begin
  let m := n.factorial + 1,
  let p := min_fac m,
  use p,
  -- use the smallest prime factor of n! + 1.

  have p_is_prime : prime p := min_fac_prime (ne_of_gt (succ_lt_succ (factorial_pos n))),
  -- proof that p is prime

  split,
  -- break the "and" into two propositions

  begin
    -- proof that p is prime
    exact p_is_prime,
  end,

  begin
  -- proof that n is less than or equal to p

    by_contradiction h, push_neg at h,
    -- proof by contradiction
    -- suppose instead that p is less than n

    have p_dvd_n : p ∣ n.factorial := dvd_factorial (min_fac_pos _) (le_of_lt h),
    -- then p divides n!

    have p_dvd_one : p ∣ 1 := (nat.dvd_add_iff_right p_dvd_n).2 (min_fac_dvd _),
    -- because p divides n! and n! + 1, p divides 1

    exact p_is_prime.not_dvd_one p_dvd_one,
    -- but this is not possible
  end,
end
