#! /usr/bin/perl
use v5.32;
use warnings;
use POSIX qw(strftime);

my $fileName = $ARGV[0];
my %questions;

my $date = strftime "%Y%m%d-%H%M%S-", localtime;

sub filename_format {
	my @filename_values = split('/', $fileName);
	my $newFileName = "$date" . "$filename_values[-1]";
	return $newFileName;
}

my $newFileName = filename_format();

open(my $fh,'<', $fileName) or die $!;
open(my $writeFile, '>', $newFileName) or die $!;

while (<$fh>) {
    if($_=~/^\d+\.\s\S/)
    {
		my $question_line = $_;
		# checks if there is a linebreak for question
		while(<$fh>) {
			my $line = $_;
			$line =~ s/^\s+|\s+$//g;
			last if /^\n/;
			chomp $question_line;
			$question_line = $question_line . " $line\n";
		}
		print {$writeFile} "$question_line\n";
		my $counter = 1;
		while(<$fh>) {
			last if /^_+/;
			my $line = $_;
			$line =~ s/^\s+|\s+$//g;
		
			# only adds line if it it starts with "[.]"
			if($line =~ /^\[.\]/) {
				if ($line =~ /^\[\S\]/) {
					substr($line, 0, 4) = "[ ] ";
				}
				$questions{$question_line}{"question$counter"} = $line;
				$counter++;
			}
			else {
				print {$writeFile} $line;
			}
		}
		foreach my $key (keys %{$questions{$question_line}}) {
			print {$writeFile} "\x20\x20\x20\x20$questions{$question_line}{$key}\n";
		}
		print {$writeFile} "\n"; print {$writeFile} ("_"x80); print {$writeFile} "\n";
    }
	
    else
    {
		print {$writeFile} $_;
        next;
    }
}

close $fh or die $!;
close $writeFile or die $!;