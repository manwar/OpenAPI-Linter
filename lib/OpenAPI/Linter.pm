package OpenAPI::Linter;

use strict;
use warnings;
use JSON::Validator;
use JSON qw(decode_json);
use YAML::XS qw(LoadFile);
use File::Slurp qw(read_file);

our $VERSION = '0.01';

sub new {
    my ($class, %args) = @_;

    my $spec;
    if ($args{file}) {
        my $file = $args{file};
        if ($file =~ /\.ya?ml$/i) {
            $spec = LoadFile($file);
        }
        else {
            $spec = decode_json(read_file($file));
        }
    }
    else {
        $spec = $args{spec} or die "spec => HASHREF required if no file";
    }

    my $version = $args{version} || '3.0.3';

    return bless {
        spec    => $spec,
        issues  => [],
        version => $version,
    }, $class;
}

sub lint {
    my ($self) = @_;

    my $spec = $self->{spec} || {};
    my @issues;

    # Check OpenAPI root keys
    foreach my $key (qw/openapi info paths/) {
        push @issues, {
            level   => 'ERROR',
            message => "Missing $key"
        } unless $spec->{$key};
    }

    # Info checks
    if ($spec->{info}) {
        my $info = $spec->{info};
        push @issues, {
            level   => 'ERROR',
            message => 'Missing info.title'
        } unless $info->{title};
        push @issues, {
            level   => 'ERROR',
            message =>'Missing info.version'
        } unless $info->{version};
        push @issues, {
            level   => 'WARN',
            message => 'Missing info.description'
        } unless $info->{description};
        push @issues, {
            level   => 'WARN',
            message => 'Missing license'
        } unless $info->{license};
    }

    # Paths / operations
    if ($spec->{paths}) {
        for my $path (keys %{$spec->{paths}}) {
            for my $method (keys %{$spec->{paths}{$path}}) {
                my $op = $spec->{paths}{$path}{$method};
                push @issues, {
                    level   => 'WARN',
                    message => "Missing description for $method $path"
                } unless $op->{description};
            }
        }
    }

    # Components / schemas
    if ($spec->{components} && $spec->{components}{schemas}) {
        for my $name (keys %{$spec->{components}{schemas}}) {
            my $schema = $spec->{components}{schemas}{$name};
            push @issues, {
                level   => 'WARN',
                message => "Schema $name missing type"
            } unless $schema->{type};

            if ($schema->{properties}) {
                for my $prop (keys %{$schema->{properties}}) {
                    push @issues, {
                        level   => 'WARN',
                        message => "Schema $name.$prop missing description"
                    } unless $schema->{properties}{$prop}{description};
                }
            }
        }
    }

    $self->{issues} = \@issues;

    return $self;
}

sub find_issues {
    my ($self, %opts) = @_;

    my $pattern = $opts{pattern};
    my $level   = $opts{level};
    my @result  = grep {
        (!defined($level)   || $_->{level}   eq $level)     &&
        (!defined($pattern) || $_->{message} =~ /$pattern/)
    } @{ $self->{issues} };

    return wantarray ? @result : \@result;
}

sub validate_schema {
    my ($self) = @_;

    my $validator = JSON::Validator->new;

    # Map of OpenAPI versions to their schema URLs
    my %schema_urls = (
        '3.0.0' => 'https://spec.openapis.org/oas/3.0/schema/2021-09-28',
        '3.0.1' => 'https://spec.openapis.org/oas/3.0/schema/2021-09-28',
        '3.0.2' => 'https://spec.openapis.org/oas/3.0/schema/2021-09-28',
        '3.0.3' => 'https://spec.openapis.org/oas/3.0/schema/2021-09-28',
        '3.1.0' => 'https://spec.openapis.org/oas/3.1/schema/2022-10-07',
        '3.1.1' => 'https://spec.openapis.org/oas/3.1/schema/2022-10-07',
    );

    my $version    = $self->{version};
    my $schema_url = $schema_urls{$version};

    unless ($schema_url) {
        if ($version =~ /^3\.1/) {
            $schema_url = 'https://spec.openapis.org/oas/3.1/schema/2022-10-07';
        } elsif ($version =~ /^3\.0/) {
            $schema_url = 'https://spec.openapis.org/oas/3.0/schema/2021-09-28';
        } else {
            die "Unsupported OpenAPI version: $version";
        }
    }

    return $validator->schema($schema_url)->validate($self->{spec});
}

1;
