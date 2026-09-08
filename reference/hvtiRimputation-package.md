# hvtiRimputation: Missing Value Imputation for the HVTI CORR Group

Fills missing values in a data frame by a stated method and returns the
filled data together with a row-level record of exactly which values
were changed. Ports the mean-imputation behaviour of the Cleveland
Clinic CORR group's SAS library – 'PROC STANDARD' with 'REPLACE', and
the 'imputsub' macro that wraps it. The package knows nothing about the
warehouse, a build, or any study: the input is a data frame and the
output is a data frame plus a record.

## Details

**A data frame in, a data frame and a record out.** That is the whole
scope. The package knows nothing about the warehouse, the build, or any
study; any manifest or provenance context belongs to the caller.

**Two entry points, never one.**
[`impute_mean()`](https://ehrlinger.github.io/hvtiRimputation/reference/impute_mean.md)
fills each missing value with its variable's mean and returns one
completed dataset (`PROC STANDARD ... REPLACE`, which the `imputsub`
macro wraps). `impute_multiple()` will generate `m` completed datasets
for use with a pooling step (`PROC MI` / `mult_imput`); it is designed
but not yet implemented.

There is deliberately no single `impute()` with a `method=` argument.
223 studies in the corpus call single mean imputation, 326 call multiple
imputation, and 18 call both. They are different methods with different
inferential properties, and a function that quietly does one when the
caller expected the other is a worse failure than no function at all –
which is exactly what a `method=` argument with a default would be. Two
functions cannot be confused by omission.

**Nothing inherits a SAS default.** `PROC STANDARD` with no `VAR`
statement processes every numeric column, and
[`impute_mean()`](https://ehrlinger.github.io/hvtiRimputation/reference/impute_mean.md)
requires `vars` anyway; `impute_multiple()` will require `m`. The reason
is that the corpus has no single answer to inherit. Five macro names
exist in copies declaring different `NIMPUTE` defaults and three of them
straddle 1, so a plurality default would silently convert a
single-imputation call site into multiple imputation – a change of
method under an unchanged call. Where this package has a default it is
*ours*, and its documentation says so rather than claiming parity.

**What it promises about reproducing SAS.** For a call that states its
`NIMPUTE` outright, the method and `m` are facts and an R run can be
checked against the study's saved output. For a call settled only by the
copy of the macro sitting in the calling study, that is strong evidence
and not proof: which copy SAS loaded depends on the autocall path and
`%include` order at run time. A study being reproduced takes its `m`
from that study's own saved output, never from the macro it called – the
macro cannot tell you; the log can. There is no general "reproduces the
corpus" guarantee, and no implementation choice here could create one.

**The record is the point.** Everything returns a logical matrix
parallel to the data saying which values were filled, because a count
cannot answer *was this patient's value imputed?*. See
[hvti_imputation](https://ehrlinger.github.io/hvtiRimputation/reference/hvti_imputation.md).

**The record must never claim a fill that did not happen**, which is why
this package refuses inputs a more relaxed one would accept: a column
whose mean is not finite, a classed numeric whose storage rules it does
not know, and a data frame with duplicated column names. Each of those
produces a record that reads as authoritative and is wrong, and a wrong
record is worse than a refusal because nothing downstream can detect it.

## See also

Useful links:

- <https://github.com/ehrlinger/hvtiRimputation>

- <https://ehrlinger.github.io/hvtiRimputation/>

- Report bugs at <https://github.com/ehrlinger/hvtiRimputation/issues>

## Author

**Maintainer**: John Ehrlinger <ehrlinj@ccf.org>

Authors:

- John Ehrlinger <ehrlinj@ccf.org>
