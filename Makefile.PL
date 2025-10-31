use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'OpenAPI::Linter',
    VERSION_FROM => 'lib/OpenAPI/Linter.pm',
    ABSTRACT     => 'Lint and validate OpenAPI specification files',
    AUTHOR       => 'Your Name <you@example.com>',
    LICENSE      => 'perl',
    EXE_FILES    => ['script/openapi-lint'],
    PREREQ_PM    => {
        'JSON::Validator' => 0,
        'YAML::XS'        => 0,
        'JSON'            => 0,
        'File::Slurp'     => 0,
    },
);

