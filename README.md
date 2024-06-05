# primemath

## Prime factorization projects

### Factoring Pi

The initial impetus for this project! Factoring the digits of &pi; (3.14159...) as decimal expansion 3, 31, 314, 3141, 31415, 314159, ... also known as [OEIS A078604](https://oeis.org/A078604).

The first 200 digits of &pi; were completed in 2023, with the final stragglers submitted by [ejeancolas](https://github.com/ejeancolas).

As of early 2024 there are 53 items in the sequence below 314 digits that remain unfactored. ECM curves 1-8 have been thoroughly covered.  Curve 9 has been run to spec (see *Curves* below) but hasn't yet been exhausted. Curves 10-13 are in progress and have yielded some remaining factors.


### Factoring RSA Numbers

The [RSA Numbers](https://en.wikipedia.org/wiki/RSA_numbers) were added in 2020, shortly before RSA-232 and RSA-250 were announced.


### Factoring HP49

A friend told me about [Home Primes](https://en.wikipedia.org/wiki/Home_prime) and that he was working on `HP49(119)` around the same time, so I added that to the queue alongside RSA and &pi;.  It has apparently eluded factorization for almost a decade since its discovery at this point, and has burned through most / all of the *Curves* below several times over.


### Curves

Based on curves from [Mersenne Wiki "Elliptic Curve Method"](https://web.archive.org/web/20160916195757/https://www.mersennewiki.org/index.php/Elliptic_curve_method#Choosing_the_best_parameters_for_ECM)


| Digits | B1             | GMP-ECM B2            | Curves  |
|--------|----------------|-----------------------|---------|
|   15   | 2,000          | 147,396               |         |
|   20   | 11,000         | 1,873,422             | 86      |
|   25   | 50,000         | 12,746,592            | 214     |
|   30   | 250,000        | 128,992,510           | 430     |
|   35   | 1,000,000      | 1,045,563,762         | 910     |
|   40   | 3,000,000      | 5,706,890,290         | 2,351   |
|   45   | 11,000,000     | 35,133,391,030        | 4,482   |
|   50   | 43,000,000     | 240,490,660,426       | 7,557   |
|   55   | 110,000,000    | 776,278,396,540       | 17,884  |
|   60   | 260,000,000    | 3,178,559,884,516     | 42,057  |
|   65   | 850,000,000    | 15,892,628,251,516    | 69,471  |
|   70   | 2,900,000,000  | 105,101,237,217,912   | 102,212 |
|   75   | 7,600,000,000  | 425,332,376,469,022   | 188,056 |
|   80   | 25,000,000,000 | 2,551,982,328,195,322 | 265,557 |

#### Usage

 * Start with a composite `X = N * M` where `N &cong; M` and `D = log10(N)`
 * Look up `D` in the `Digits` column to find your row
 * If your `D` is between rows, either pick the larger value or pick a number between the two values
 * Find the `B1` value  and `Curves` count

With these, you have the parameters for `ecm`:
```
echo ${X} | ecm -one -c ${CURVES} ${B1}
```

ECM will set the `B2` parameter appropriately to match these table values, or you can specify it as
```
echo ${X} | ecm -one -c ${CURVES} ${B1} ${B2}
```

If `N &Gt; M` you should use `D = log10(M)` to find the smaller factor more efficiently.
