use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Tie::RangeHash',
    'VERSION_FROM'	=> 'RangeHash.pm', # finds $VERSION
    'PREREQ_PM'		=> {
       'Carp'               => 0,
       'Carp::Assert'       => 0.17,
       'List::SkipList'     => 0.12, # 0.13 is preferred
     },
  ($] ge '5.005') ? (
    'AUTHOR'   => 'Robert Rothenberg <rrwo@cpan.org>',
    'ABSTRACT' => 'Allows hashes to associate values with a range of keys',
  ) : (),
);
