#!/usr/bin/env raku

# This script reads the native_array.pm6 file, and generates the intarray,
# numarray and strarray roles in it, and writes it back to the file.

# always use highest version of Raku
use v6.*;

my $generator = $*PROGRAM-NAME;
my $generated = DateTime.now.gist.subst(/\.\d+/,'');
my $start     = '#- start of generated part of ';
my $idpos     = $start.chars;
my $idchars   = 3;
my $end       = '#- end of generated part of ';

# slurp the whole file and set up writing to it
my $filename = "src/core.c/native_array.pm6";
my @lines = $filename.IO.lines;
$*OUT = $filename.IO.open(:w);

# for all the lines in the source that don't need special handling
while @lines {
    my $line := @lines.shift;

    # nothing to do yet
    unless $line.starts-with($start) {
        say $line;
        next;
    }

    # found shaped header, ignore
    my $type = $line.substr($idpos,$idchars);
    if $type eq 'sha' {
        say $line;
        next;
    }

    # found header
    die "Don't know how to handle $type" unless $type eq "int" | "num" | "str";
    say $start ~ $type ~ "array role -----------------------------------";
    say "#- Generated on $generated by $generator";
    say "#- PLEASE DON'T CHANGE ANYTHING BELOW THIS LINE";

    # skip the old version of the code
    while @lines {
        last if @lines.shift.starts-with($end);
    }

    # set up template values
    my %mapper =
      postfix => $type.substr(0,1),
      type    => $type,
      Type    => $type.tclc,
      nullval => $type eq 'str' ?? '""' !! $type eq 'num' ?? '0e0' !! '0'
    ;

    # spurt the role
    say Q:to/SOURCE/.subst(/ '#' (\w+) '#' /, -> $/ { %mapper{$0} }, :g).chomp;

        multi method grep(#type#array:D: #Type#:D $needle, :$k, :$kv, :$p, :$v --> Seq:D) {
            my int $i     = -1;
            my int $elems = nqp::elems(self);
            my $result   := nqp::create(IterationBuffer);

            if $k {
                nqp::while(
                  nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
                  nqp::if(
                    nqp::iseq_#postfix#(nqp::atpos_#postfix#(self,$i),$needle),
                    nqp::push($result,nqp::clone($i))
                  )
                );
            }
            elsif $kv {
                nqp::while(
                  nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
                  nqp::if(
                    nqp::iseq_#postfix#(nqp::atpos_#postfix#(self,$i),$needle),
                    nqp::stmts(
                      nqp::push($result,nqp::clone($i)),
                      nqp::push($result,$needle)
                    )
                  )
                );
            }
            elsif $p {
                nqp::while(
                  nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
                  nqp::if(
                    nqp::iseq_#postfix#(nqp::atpos_#postfix#(self,$i),$needle),
                    nqp::push($result,Pair.new($i,$needle))
                  )
                );
            }
            else {
                my int $found;
                nqp::while(
                  nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
                  nqp::if(
                    nqp::iseq_#postfix#(nqp::atpos_#postfix#(self,$i),$needle),
                    nqp::push($result,$needle)
                  )
                );
            }
            $result.Seq
        }

        multi method first(#type#array:D: #Type#:D $needle, :$k, :$kv, :$p, :$v) {
            my int $i     = -1;
            my int $elems = nqp::elems(self);

            nqp::while(
              nqp::islt_i(($i = nqp::add_i($i,1)),$elems)
                && nqp::isne_#postfix#(nqp::atpos_#postfix#(self,$i),$needle),
              nqp::null()
            );

            nqp::iseq_i($i,nqp::elems(self))
              ?? Nil
              !! $k
                ?? $i
                !! $kv
                  ?? ($i,$needle)
                  !! $p
                    ?? Pair.new($i,$needle)
                    !! $needle
        }

        multi method unique(#type#array:D:) {
            my int $i     = -1;
            my int $elems = nqp::elems(self);
            my $result := nqp::create(array[self.of]);
            my $seen   := nqp::hash;

            nqp::while(
              nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
              nqp::unless(
                nqp::existskey($seen,nqp::atpos_#postfix#(self,$i)),
                nqp::bindkey($seen,nqp::push_#postfix#($result,nqp::atpos_#postfix#(self,$i)),1)
              )
            );

            $result
        }

        multi method repeated(#type#array:D:) {
            my int $i     = -1;
            my int $elems = nqp::elems(self);
            my $result := nqp::create(array[self.of]);
            my $seen   := nqp::hash;

            nqp::while(
              nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
              nqp::if(
                nqp::existskey($seen,(my #type# $key = nqp::atpos_#postfix#(self,$i))),
                nqp::push_#postfix#($result,$key),
                nqp::bindkey($seen,$key,1)
              )
            );

            $result
        }

        multi method squish(#type#array:D:) {
            if nqp::elems(self) -> int $elems {
                my $result  := nqp::create(array[self.of]);
                my #type# $last = nqp::push_#postfix#($result,nqp::atpos_#postfix#(self,0));
                my int $i;

                nqp::while(
                  nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
                  nqp::if(
                    nqp::isne_#postfix#(nqp::atpos_#postfix#(self,$i),$last),
                    nqp::push_#postfix#($result,$last = nqp::atpos_#postfix#(self,$i))
                  )
                );
                $result
            }
            else {
                self
            }
        }

        multi method AT-POS(#type#array:D: int $idx --> #type#) is raw {
            nqp::islt_i($idx,0)
              ?? INDEX_OUT_OF_RANGE($idx)
              !! nqp::atposref_#postfix#(self,$idx)
        }
        multi method AT-POS(#type#array:D: Int:D $idx --> #type#) is raw {
            $idx < 0
              ?? INDEX_OUT_OF_RANGE($idx)
              !! nqp::atposref_#postfix#(self,$idx)
        }

        multi method ASSIGN-POS(#type#array:D: int $idx, #type# $value --> #type#) {
            nqp::islt_i($idx,0)
              ?? INDEX_OUT_OF_RANGE($idx)
              !! nqp::bindpos_#postfix#(self, $idx, $value)
        }
        multi method ASSIGN-POS(#type#array:D: Int:D $idx, #type# $value --> #type#) {
            $idx < 0
              ?? INDEX_OUT_OF_RANGE($idx)
              !! nqp::bindpos_#postfix#(self, $idx, $value)
        }
        multi method ASSIGN-POS(#type#array:D: int $idx, #Type#:D $value --> #type#) {
            nqp::islt_i($idx,0)
              ?? INDEX_OUT_OF_RANGE($idx)
              !! nqp::bindpos_#postfix#(self, $idx, $value)
        }
        multi method ASSIGN-POS(#type#array:D: Int:D $idx, #Type#:D $value --> #type#) {
            $idx < 0
              ?? INDEX_OUT_OF_RANGE($idx)
              !! nqp::bindpos_#postfix#(self, $idx, $value)
        }
        multi method ASSIGN-POS(#type#array:D: Any $idx, Mu \value --> Nil) {
            X::TypeCheck.new(
                operation => "assignment to #type# array element #$idx",
                got       => value,
                expected  => T,
            ).throw;
        }

        multi method STORE(#type#array:D: $value --> #type#array:D) {
            nqp::setelems(self,1);
            nqp::bindpos_#postfix#(self, 0, nqp::unbox_#postfix#($value));
            self
        }
        multi method STORE(#type#array:D: #type#array:D \values --> #type#array:D) {
            nqp::setelems(self,nqp::elems(values));
            nqp::splice(self,values,0,nqp::elems(values))
        }
        multi method STORE(#type#array:D: Seq:D \seq --> #type#array:D) {
            nqp::if(
              (my $iterator := seq.iterator).is-lazy,
              self.throw-iterator-cannot-be-lazy('store'),
              nqp::stmts(
                nqp::setelems(self,0),
                $iterator.push-all(self),
                self
              )
            )
        }
        multi method STORE(#type#array:D: List:D \values --> #type#array:D) {
            my int $elems = values.elems;    # reifies
            my \reified := nqp::getattr(values,List,'$!reified');
            nqp::setelems(self, $elems);

            my int $i = -1;
            nqp::while(
              nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
              nqp::bindpos_#postfix#(self,$i,
                nqp::if(
                  nqp::isnull(nqp::atpos(reified,$i)),
                  #nullval#,
                  nqp::unbox_#postfix#(nqp::atpos(reified,$i))
                )
              )
            );
            self
        }
        multi method STORE(#type#array:D: @values --> #type#array:D) {
            my int $elems = @values.elems;   # reifies
            nqp::setelems(self, $elems);

            my int $i = -1;
            nqp::while(
              nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
              nqp::bindpos_#postfix#(self, $i,
                nqp::unbox_#postfix#(@values.AT-POS($i)))
            );
            self
        }

        multi method push(#type#array:D: #type# $value --> #type#array:D) {
            nqp::push_#postfix#(self, $value);
            self
        }
        multi method push(#type#array:D: #Type#:D $value --> #type#array:D) {
            nqp::push_#postfix#(self, $value);
            self
        }
        multi method push(#type#array:D: Mu \value --> Nil) {
            X::TypeCheck.new(
                operation => 'push to #type# array',
                got       => value,
                expected  => T,
            ).throw;
        }
        multi method append(#type#array:D: #type# $value --> #type#array:D) {
            nqp::push_#postfix#(self, $value);
            self
        }
        multi method append(#type#array:D: #Type#:D $value --> #type#array:D) {
            nqp::push_#postfix#(self, $value);
            self
        }
        multi method append(#type#array:D: #type#array:D $values --> #type#array:D) is default {
            nqp::splice(self,$values,nqp::elems(self),0)
        }
        multi method append(#type#array:D: @values --> #type#array:D) {
            return self.fail-iterator-cannot-be-lazy('.append')
              if @values.is-lazy;
            nqp::push_#postfix#(self, $_) for flat @values;
            self
        }

        method pop(#type#array:D: --> #type#) {
            nqp::elems(self)
              ?? nqp::pop_#postfix#(self)
              !! self.throw-cannot-be-empty('pop')
        }

        method shift(#type#array:D: --> #type#) {
            nqp::elems(self)
              ?? nqp::shift_#postfix#(self)
              !! self.throw-cannot-be-empty('shift')
        }

        multi method unshift(#type#array:D: #type# $value --> #type#array:D) {
            nqp::unshift_#postfix#(self, $value);
            self
        }
        multi method unshift(#type#array:D: #Type#:D $value --> #type#array:D) {
            nqp::unshift_#postfix#(self, $value);
            self
        }
        multi method unshift(#type#array:D: @values --> #type#array:D) {
            return self.fail-iterator-cannot-be-lazy('.unshift')
              if @values.is-lazy;
            nqp::unshift_#postfix#(self, @values.pop) while @values;
            self
        }
        multi method unshift(#type#array:D: Mu \value --> Nil) {
            X::TypeCheck.new(
                operation => 'unshift to #type# array',
                got       => value,
                expected  => T,
            ).throw;
        }

        my $empty_#postfix# := nqp::list_#postfix#;

        multi method splice(#type#array:D: --> #type#array:D) {
            my $splice := nqp::clone(self);
            nqp::setelems(self,0);
            $splice
        }
        multi method splice(#type#array:D: Int:D \offset --> #type#array:D) {
            nqp::if(
              nqp::islt_i((my int $offset = offset),0)
                || nqp::isgt_i($offset,(my int $elems = nqp::elems(self))),
              Failure.new(X::OutOfRange.new(
                :what('Offset argument to splice'),
                :got($offset),
                :range("0..{nqp::elems(array)}")
              )),
              nqp::if(
                nqp::iseq_i($offset,nqp::elems(self)),
                nqp::create(self.WHAT),
                nqp::stmts(
                  (my $slice := nqp::slice(self,$offset,-1)),
                  nqp::splice(
                    self,
                    $empty_#postfix#,
                    $offset,
                    nqp::sub_i(nqp::elems(self),$offset)
                  ),
                  $slice
                )
              )
            )
        }
        multi method splice(#type#array:D: Int:D $offset, Int:D $size --> #type#array:D) {
            nqp::unless(
              nqp::istype(
                (my $slice := CLONE_SLICE(self,$offset,$size)),
                Failure
              ),
              nqp::splice(self,$empty_#postfix#,$offset,$size)
            );
            $slice
        }
        multi method splice(#type#array:D: Int:D $offset, Int:D $size, #type#array:D \values --> #type#array:D) {
            nqp::unless(
              nqp::istype(
                (my $slice := CLONE_SLICE(self,$offset,$size)),
                Failure
              ),
              nqp::splice(
                self,
                nqp::if(nqp::eqaddr(self,values),nqp::clone(values),values),
                $offset,
                $size
              )
            );
            $slice
        }
        multi method splice(#type#array:D: Int:D $offset, Int:D $size, Seq:D \seq --> #type#array:D) {
            nqp::if(
              seq.is-lazy,
              self.throw-iterator-cannot-be-lazy('.splice'),
              nqp::stmts(
                nqp::unless(
                  nqp::istype(
                    (my $slice := CLONE_SLICE(self,$offset,$size)),
                    Failure
                  ),
                  nqp::splice(self,nqp::create(self).STORE(seq),$offset,$size)
                ),
                $slice
              )
            )
        }
        multi method splice(#type#array:D: $offset=0, $size=Whatever, *@values --> #type#array:D) {
            return self.fail-iterator-cannot-be-lazy('splice in')
              if @values.is-lazy;

            my int $elems = nqp::elems(self);
            my int $o = nqp::istype($offset,Callable)
              ?? $offset($elems)
              !! nqp::istype($offset,Whatever)
                ?? $elems
                !! $offset.Int;
            my int $s = nqp::istype($size,Callable)
              ?? $size($elems - $o)
              !! !defined($size) || nqp::istype($size,Whatever)
                 ?? $elems - ($o min $elems)
                 !! $size.Int;

            unless nqp::istype(
              (my $splice := CLONE_SLICE(self,$o,$s)),
              Failure
            ) {
                my $splicees := nqp::create(self);
                nqp::push_#postfix#($splicees, @values.shift) while @values;
                nqp::splice(self,$splicees,$o,$s);
            }
            $splice
        }

        multi method min(#type#array:D:) {
            nqp::if(
              (my int $elems = nqp::elems(self)),
              nqp::stmts(
                (my int $i),
                (my #type# $min = nqp::atpos_#postfix#(self,0)),
                nqp::while(
                  nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
                  nqp::if(
                    nqp::islt_#postfix#(nqp::atpos_#postfix#(self,$i),$min),
                    ($min = nqp::atpos_#postfix#(self,$i))
                  )
                ),
                $min
              ),
              Inf
            )
        }
        multi method max(#type#array:D:) {
            nqp::if(
              (my int $elems = nqp::elems(self)),
              nqp::stmts(
                (my int $i),
                (my #type# $max = nqp::atpos_#postfix#(self,0)),
                nqp::while(
                  nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
                  nqp::if(
                    nqp::isgt_#postfix#(nqp::atpos_#postfix#(self,$i),$max),
                    ($max = nqp::atpos_#postfix#(self,$i))
                  )
                ),
                $max
              ),
              -Inf
            )
        }
        multi method minmax(#type#array:D: --> Range:D) {
            nqp::if(
              (my int $elems = nqp::elems(self)),
              nqp::stmts(
                (my int $i),
                (my #type# $min =
                  my #type# $max = nqp::atpos_#postfix#(self,0)),
                nqp::while(
                  nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
                  nqp::if(
                    nqp::islt_#postfix#(nqp::atpos_#postfix#(self,$i),$min),
                    ($min = nqp::atpos_#postfix#(self,$i)),
                    nqp::if(
                      nqp::isgt_#postfix#(nqp::atpos_#postfix#(self,$i),$max),
                      ($max = nqp::atpos_#postfix#(self,$i))
                    )
                  )
                ),
                Range.new($min,$max)
              ),
              Range.new(Inf,-Inf)
            )
        }
        method iterator(#type#array:D: --> PredictiveIterator:D) {
            Rakudo::Iterator.native_#postfix#(self)
        }
        method Seq(#type#array:D: --> Seq:D) {
            Seq.new(Rakudo::Iterator.native_#postfix#(self))
        }

        method reverse(#type#array:D: --> #type#array:D) is nodal {
            nqp::stmts(
              (my int $elems = nqp::elems(self)),
              (my int $last  = nqp::sub_i($elems,1)),
              (my int $i     = -1),
              (my $to := nqp::clone(self)),
              nqp::while(
                nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
                nqp::bindpos_#postfix#($to,nqp::sub_i($last,$i),
                  nqp::atpos_#postfix#(self,$i))
              ),
              $to
            )
        }
        method rotate(#type#array:D: Int(Cool) $rotate = 1 --> #type#array:D) is nodal {
            nqp::stmts(
              (my int $elems = nqp::elems(self)),
              (my $to := nqp::clone(self)),
              (my int $i = -1),
              (my int $j =
                nqp::mod_i(nqp::sub_i(nqp::sub_i($elems,1),$rotate),$elems)),
              nqp::if(nqp::islt_i($j,0),($j = nqp::add_i($j,$elems))),
              nqp::while(
                nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
                nqp::bindpos_#postfix#(
                  $to,
                  ($j = nqp::mod_i(nqp::add_i($j,1),$elems)),
                  nqp::atpos_#postfix#(self,$i)
                ),
              ),
              $to
            )
        }
        multi method sort(#type#array:D: --> #type#array:D) {
            Rakudo::Sorting.MERGESORT-#type#(nqp::clone(self))
        }

        multi method ACCEPTS(#type#array:D: #type#array:D \o --> Bool:D) {
            nqp::hllbool(
              nqp::unless(
                nqp::eqaddr(self,my \other := nqp::decont(o)),
                nqp::if(
                  nqp::iseq_i(
                    (my int $elems = nqp::elems(self)),
                    nqp::elems(other)
                  ),
                  nqp::stmts(
                    (my int $i = -1),
                    nqp::while(
                      nqp::islt_i(($i = nqp::add_i($i,1)),$elems)
                        && nqp::iseq_#postfix#(
                             nqp::atpos_#postfix#(self,$i),
                             nqp::atpos_#postfix#(other,$i)
                           ),
                      nqp::null
                    ),
                    nqp::iseq_i($i,$elems)
                  )
                )
              )
            )
        }
        proto method grab(|) {*}
        multi method grab(#type#array:D: --> #type#) {
            nqp::elems(self) ?? self.GRAB_ONE !! Nil
        }
        multi method grab(#type#array:D: Callable:D $calculate --> #type#) {
            self.grab($calculate(nqp::elems(self)))
        }
        multi method grab(#type#array:D: Whatever --> Seq:D) { self.grab(Inf) }

        my class GrabN does Iterator {
            has $!array;
            has int $!count;

            method !SET-SELF(\array,\count) {
                nqp::stmts(
                  (my int $elems = nqp::elems(array)),
                  ($!array := array),
                  nqp::if(
                    count == Inf,
                    ($!count = $elems),
                    nqp::if(
                      nqp::isgt_i(($!count = count.Int),$elems),
                      ($!count = $elems)
                    )
                  ),
                  self
                )

            }
            method new(\a,\c) { nqp::create(self)!SET-SELF(a,c) }
            method pull-one() {
                nqp::if(
                  $!count && nqp::elems($!array),
                  nqp::stmts(
                    ($!count = nqp::sub_i($!count,1)),
                    $!array.GRAB_ONE
                  ),
                  IterationEnd
                )
            }
            method is-deterministic(--> False) { }
        }
        multi method grab(#type#array:D: \count --> Seq:D) {
            Seq.new(
              nqp::elems(self)
                ?? GrabN.new(self,count)
                !! Rakudo::Iterator.Empty
            )
        }

        method GRAB_ONE(#type#array:D: --> #type#) is implementation-detail {
            nqp::stmts(
              (my $value := nqp::atpos_#postfix#(
                self,
                (my int $pos = nqp::floor_n(nqp::rand_n(nqp::elems(self))))
              )),
              nqp::splice(self,$empty_#postfix#,$pos,1),
              $value
            )
        }
SOURCE

    # we're done for this role
    say "#- PLEASE DON'T CHANGE ANYTHING ABOVE THIS LINE";
    say $end ~ $type ~ "array role -------------------------------------";
}

# close the file properly
$*OUT.close;

# vim: expandtab sw=4
