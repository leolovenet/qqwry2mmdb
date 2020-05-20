#!/usr/bin/env perl
use lib 'lib';

use utf8;
binmode STDOUT, "encoding(UTF-8)";

use strict;
use warnings FATAL => 'all';

use IP::QQWry::Dumper;
use MaxMind::DB::Writer::Tree;

use feature qw(say);

my $qqwry_file = $ARGV[0] // $ENV{IPDB_QQWRY_PATH};
die "The path to the qqwry.data file must be given, or set to the environment variable IPDB_QQWRY_PATH" unless $qqwry_file;
my $qqwry = IP::QQWry::Dumper->new($qqwry_file);

# document https://metacpan.org/pod/MaxMind::DB::Writer::Tree
my %types = (
    country => 'map',
    city    => 'map',
    names   => 'map',
    en      => 'utf8_string'
);
my $tree = MaxMind::DB::Writer::Tree->new(
    ip_version               => 4,
    record_size              => 28,
    database_type            => 'QQWry-Data',
    languages                => [ 'en', 'zh-CN' ],
    description              => {
        en      => 'QQWry database',
        'zh-CN' => ($qqwry->db_version() // "") . " CZ88.NET",
    },
    map_key_type_callback    => sub {$types{ $_[0] }},
    remove_reserved_networks => 1, #为 1 时删除私网网段内的IP记录，为 0 则保留
);

$qqwry->iterate(sub {
    my ($idx, $sip, $eip, $base, $ext) = @_;

    #wireshark 只读取 city.names.en 与 country.names.en 这两组数据
    $tree->insert_range($sip, $eip, {
        city    => {
            names => {
                en => $base
            }
        },
        country => {
            names => {
                en => $ext
            }
        }
    });

    # if ($sip eq $eip) {
    #     say join ' ', ($idx, $sip, $base, $ext);
    # }
    #
    # if ($idx > 10000) {
    #     # iterator will stop if we return 0
    #     return 0;
    # }

    return 1;
});

# $tree->insert_range("127.0.0.1", "127.0.0.1", {
#     city    => {
#         names => {
#             en => "众里寻她千百度，蓦然回首阑珊处"
#         }
#     },
#     country => {
#         names => {
#             en => "就是您"
#         }
#     }
# });

# Write the database to disk.
my $dbfile = 'qqwry.mmdb';
open(my $fh, '>:raw', $dbfile);
$tree->write_tree($fh);
close $fh or die "Close file $dbfile: $!";

print "$dbfile has now been created\n";

