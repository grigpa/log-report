package HtmlReport;

use strict;
use warnings;
use Template;
use File::Basename qw(dirname);
use File::Path qw(make_path);

sub new {
    my ($class, %args) = @_;
    die "Missing template path\n" unless $args{template};

    return bless { template => $args{template} }, $class;
}

sub render {
    my ($self, $data, $output_file) = @_;

    my $dir = dirname($output_file);
    make_path($dir) if $dir && !-d $dir;

    my $tt = Template->new({ ENCODING => 'utf8' });

    $tt->process(
        $self->{template},
        $data,
        $output_file,
        { binmode => ':utf8' }
    ) or die $tt->error();
}

1;
