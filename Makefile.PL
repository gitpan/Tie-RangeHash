use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Tie::RangeHash',
    'VERSION_FROM'	=> 'RangeHash.pm', # finds $VERSION
    'PREREQ_PM'		=> {
       'warnings::register' => 0, # enforce Perl 5.6.0
       'Carp'               => 0,
     },
  ($] ge '5.005') ? (
    'AUTHOR'   => 'Robert Rothenberg (rrwo@cpan.org)',
    'ABSTRACT' => 'Allows hashes to associate values with a range of keys',
  ) : (),
);
