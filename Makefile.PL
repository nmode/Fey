use ExtUtils::MakeMaker;

WriteMakefile(
    NAME => 'App::Fey',
    VERSION_FROM => 'lib/App/Fey.pm',
    ABSTRACT_FROM => 'lib/App/Fey.pm',
    LICENSE => 'open_source',
    AUTHOR => 'Naeem Model <me@nmode.ca>',
    EXE_FILES => ['script/fey'],
);
