use Module::Build;

my $build = Module::Build->new
    (
     module_name => 'Tie::RangeHash',
     license => 'perl',
     requires => {
       'perl'                       => '5.6.1',
       'base'                       => 0,
       'Algorithm::SkipList'        => 1.00,
       'Test::More'                 => 0,
     },
     recommends => {
       'Carp::Assert'               => 0,
     },
#      autosplit  => [qw(
#        lib/Tie/RangeHash.pm
#      )],
     create_makefile_pl => 'traditional',
     dist_author        => 'Robert Rothenberg <rrwo at cpan.org>',
);

$build->create_build_script;
