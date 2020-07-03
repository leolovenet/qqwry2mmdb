package IP::QQWry::Dumper;

use 5.008;
use warnings;
use strict;
use base 'IP::QQWry::Decoded';
use Encode;
use Socket;

use feature qw(say);

# https://www.perl.com/article/creating-ip-address-tools-from-scratch/
sub long2ip {
    my $decimal = shift;
    my @bytes = unpack 'CCCC', pack 'N', $decimal;
    return join '.', @bytes;
}

sub iterate {
    my $self = shift;
    my $callback = shift;
    die 'must give callback subroutines' unless defined $callback;

    my $index;
    my $end = ($self->{last_index} - $self->{first_index}) / 7;

    for ($index = 0; $index < $end; $index++) {
        my ($ip_start, $ip_end, $offset, $tmp);

        seek $self->{fh}, $self->{first_index} + $index * 7, 0;
        read $self->{fh}, $tmp, 4;
        $ip_start = unpack 'V', $tmp;

        read $self->{fh}, $tmp, 3;
        $offset = unpack 'V', $tmp . chr 0;
        die 'record index out of range' unless ($offset >= 8 && $offset < $self->{first_index});

        seek $self->{fh}, $offset, 0;
        read $self->{fh}, $tmp, 4;
        $ip_end = unpack 'V', $tmp;

        my ($base, $ext) = (q{}) x 2;
        read $self->{fh}, $tmp, 1;
        my $mode = ord $tmp;

        if ($mode == 1) {
            $self->_seek;
            $offset = tell $self->{fh};
            read $self->{fh}, $tmp, 1;
            $mode = ord $tmp;
            if ($mode == 2) {
                $self->_seek;
                $base = $self->_str;
                seek $self->{fh}, $offset + 4, 0;
                $ext = $self->_ext;
            }
            else {
                seek $self->{fh}, -1, 1;
                $base = $self->_str;
                $ext = $self->_ext;
            }
        }
        elsif ($mode == 2) {
            $self->_seek;
            $base = $self->_str;
            seek $self->{fh}, $offset + 8, 0;
            $ext = $self->_ext;
        }
        else {
            seek $self->{fh}, -1, 1;
            $base = $self->_str;
            $ext = $self->_ext;
        }

        # 'CZ88.NET' means we don't have useful information
        $base = '' if $base =~ /CZ88\.NET/;
        $ext = '' if $ext =~ /CZ88\.NET/;

        my @ret = ($base, $ext);
        my @converted;

        if ($self->encoding) {
            @converted = map {decode($self->encoding, $_)} @ret;
        }
        else {
            # then it's either gbk or big5
            eval {
                @converted = map {decode('gbk', $_)} @ret;
            };

            if ($@) {
                @converted = map {decode('big5', $_)} @ret;
            }
        }
        die "failed to decode" unless @converted;

        unshift @converted, long2ip($ip_start), long2ip($ip_end);

        last unless $callback->($index, @converted);
    }
}

sub dump {
    my $self = shift;
    $self->iterate(sub {
        say join ' ', @_;
        return 1;
    })
}

1;

__END__
