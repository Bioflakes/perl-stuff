#! /usr/bin/perl
use v5.32;
use warnings;
# Extension 1
use Text::Levenshtein qw(distance);

my $master_file = shift @ARGV;
my %questions;
my %student_results;
# Extension 1
my %questions_fulltext;
my %answers_fulltext;


# adds questions, their answers and whether they are
# correct or not to an internal hashmap
sub add_question {
	my ($question_key, $answer, $correct) = @_;
	my $length = keys %{$questions{$question_key}};
	$questions{$question_key}{$answer} = $correct;
}
# checks whether answer is marked correct or not
# returns: boolean
sub check_answer_correctness {
	my ($answer) = @_;
	my $correct = 0;
	if ($answer =~ /^\[X\]/) {
		$correct = 1;
	}
	return $correct;	
}

# Extension 1
sub normalize {
	my ($question_line) = @_;
	# turn question to lowercase
	$question_line = lc($question_line);
	# stop words array, join every element with '|' seperator
	my @stop_words = ("also", "and", "after", "are", "a", "an", "as", "at", "the", "that", "this", "to", "of", "or", "in", "it", "if", "be", "by",
	"but", "did", "doing", "was", "where", "what", "will", "which", "you", "is", "can", "for", "how", "many", "not", "should");
	my $regex_stop_words = join '|', @stop_words;
	# remove stopwords, remove sequence whitespaces
	$question_line =~ s/\b(?:$regex_stop_words)\s//g;
	
	return $question_line;
}


open(my $master_fh,'<', $master_file) or die $!;

while (<$master_fh>) {
	# entered a question block
    if($_=~/^\d+\.\s\S/) {
		my $question_line = $_;
		# checks if there is a linebreak for question
		while(<$master_fh>) {
			my $line = $_;
			$line =~ s/^\s+|\s+$//g;
			last if /^\n/;
			chomp $question_line;
			$question_line = $question_line . " $line\n";
		}
		
		# possible entrypoint for Extension 1
		# $question_line
		my $question_line_norm = normalize($question_line);
		$questions_fulltext{$question_line_norm} = $question_line;
		
		while(<$master_fh>) {
			last if /^_+/;
			my $line = $_;
			$line =~ s/^\s+|\s+$//g;
			
			# only adds line if it it starts with "[.]"
			if ($line =~ /^\[.\]/) {
				my $marked = substr($line, 0, 3);
				my $is_correct = check_answer_correctness($marked);
				substr($line, 0, 4) = "";
				my $line_norm = normalize($line);
				$answers_fulltext{$line_norm} = $line;
				add_question($question_line_norm, $line_norm, $is_correct);
			}
		}
	}

	else {
        next;
    }
}
close $master_fh or die $!;

# levenshtein function for single string comparisons (question titles)
sub levenshtein {
	my ($master_string, $student_string) = @_;
	my $max_edit_distance = 0.1;

	#print "\ncomparing:\t$master_string with\t$student_string\n";
	
	my $dist = distance($master_string, $student_string);
	my $size = length $master_string;
	
	if($dist <= $size*$max_edit_distance) {
		return 1;
	}
	return 0;
}
# check if it meets levenshtein criteria, then set return string
sub levenshtein_answer {
	my ($master_answer, $student_answer) = @_;
	if(levenshtein($master_answer, $student_answer)) {
		return $student_answer;
	}
	return $master_answer;
}

# compares the passed hash with the in-memory hash of the master file for missing questions and answers
sub check_missing {
	my ($student, %existing_elements) = @_;
	my @missing_questions = ();
	my @missing_answers = ();
	
	foreach my $question_title (sort keys %questions) {
		unless(exists ($existing_elements{$question_title})) {
			# Extension 1
			# check if question is maybe just misspelled
			foreach my $student_question (sort keys %existing_elements) {
				my $question_title_id = $question_title;
				my $temp_qkey = $student_question;
				$temp_qkey =~ /^(\d+).\s\S/;
				my $string_tocompare = $1;
				$question_title_id =~ /^(\d+).\s\S/;
				# if both questions start with the same number
				if($string_tocompare eq $1) {
					my $leven_student_question = levenshtein_answer($question_title, $student_question);
					print "checking\n\t$leven_student_question\n";
					# it really doesn't exist
					unless(exists ($existing_elements{$leven_student_question})) {
						# push full question title to array, for better readability
						push @missing_questions, $questions_fulltext{$question_title};
					}
				}
			}
			
		}
	}
	if(scalar @missing_questions > 0) {
		print "\t$student:\n";
		foreach my $question (@missing_questions) {
			print "\t\tMissing question: $question\n";
		}
	}
	if(scalar @missing_answers > 0) {
		print "\t$student:\n";
		foreach my $answer (@missing_answers) {
			print "\t\tMissing answer: $answer\n";
		}
	}
}

sub check_results {
	my ($student, %existing_elements) = @_;
	my $count_answered_questions = 0;
	my $count_correct_questions = 0;
	
	foreach my $question_title (sort keys %questions) {
		if(exists ($existing_elements{$question_title})) {	
			# holds how many answers were answered
			my $filled_answer_count = 0;
			my $correct_answer_reached = 0;
				
			# checks how many questions were answered
			# also checks if a question was correct or not
			foreach my $answer (sort keys %{$existing_elements{$question_title}}) {
			
				# checks if a question was answered or not - only runs once, question cannot be answered "twice"
				if($existing_elements{$question_title}{$answer}) {
					$count_answered_questions++;
					$filled_answer_count++;
					# checks if the marked answer is correct
					# can only run once
					if($questions{$question_title}{$answer} && $filled_answer_count < 2) {
						$count_correct_questions++;
						$correct_answer_reached = 1;
					}
					# if two answers were marked, deduct a point
					# any following marking would be above 2, not necessary to deduct more points
					if($filled_answer_count > 1 && $correct_answer_reached) {
						$count_correct_questions--;
					}
				}
			}

		}
	}
	# set the total answered # of questions, for current student
	$student_results{$student} = "$count_correct_questions\/$count_answered_questions";
}

foreach my $student_file (@ARGV) {
	open(my $student_fh, '<', $student_file) or die $!;
	my %existing_elements = ();
	my %answered_questions = ();
	# initialize the student results hash
	$student_results{$student_file} = 0;
	
	while(<$student_fh>) {
		# entered a question block
		if($_=~/^\d+\.\s\S/) {
			my $question_line = $_;
			
			# possible entrypoint for Extension 1
			# $question_line
			$question_line = normalize($question_line);
			
			my $marked_answers = 0;
			# holds the existing questions and their answers, taken from student file
			$existing_elements{$question_line} = ();
			
			while(<$student_fh>) {
				last if /^_+/;
				my $answer = $_;
				$answer =~ s/^\s+|\s+$//g;
					
				if($answer =~ /^\[.\]/) {
					# removes the [ ] part of the answer line
					my $temp_line = substr($answer, 4, length $answer);
					$temp_line = normalize($temp_line);
					my $is_marked = 0;

					if($answer =~/^\[X\]/) {
						$is_marked = 1;
					}
					$existing_elements{$question_line}{$temp_line} = $is_marked;
				}
			}
		}
		else {
			next;
		}
	}
	# pass the existing elements and name of student to this sub
	check_missing($student_file, %existing_elements);
	# add count of total answers of this student to hash
	check_results($student_file, %existing_elements);
	
	close $student_fh or die $!;
}
print "\n"."-"x40; print "\n"."-"x16; print "RESULTS"."-"x17; print "\n"."-"x40; print "\n";
foreach my $student (sort keys %student_results) {
	print "\t$student ------- $student_results{$student}\n";
}