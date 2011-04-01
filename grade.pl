#! /usr/bin/perl -w
use strict;
my( $class_roster, $project_name, $source_file, $grade_file, $max_submissions, @expected_files);
my( $submission_path, $grade_path, $test_path, $log_file, $sleep_time );
my( $graded, $too_many_message, $wrong_file_message , $grade_message);
my($EMAIL_BUFFER, $SCORE_SUM);

#Basic project information
$project_name = "CS 161 Programming Test #5";
$max_submissions = 3;
@expected_files =("Project5.java", "Die.java", "Game.java");

#Time between grading loops, in seconds
$sleep_time = 300;

#Path to class roster file with information to be appended to each grade entry
#Should be a csv file
#$class_roster = "/nfs/farm/u1/w/weeksa/proj4_perl/cs161_winter09_students.csv";
$class_roster = "/nfs/farm/u1/w/weeksa/proj5_perl/cs161_winter09_students.csv";

#Path to java tests
#$test_path = "/nfs/farm/u1/w/weeksa/proj4_perl/tests/";
$test_path = "/nfs/farm/u1/w/weeksa/proj5_perl/tests/";

#Path to user submission directory
#$submission_path = "/nfs/farm/u1/w/weeksa/proj4_perl/submissions/";
#$submission_path = "/nfs/stak/a2/classes/eecs/winter2009/cs161/private/proj5_perl/submissions/";
$submission_path = "/nfs/farm/u1/w/weeksa/proj5_perl/submissions/";

#Path to class grade sheet
#$grade_file = "/nfs/farm/u1/w/weeksa/proj4_perl/PT4_Grades.csv";
$grade_file = "/nfs/farm/u1/w/weeksa/proj5_perl/PT5_grades.csv";

#Log file (seldom used)
$log_file = "/nfs/farm/u1/w/weeksa/proj5_perl/log.txt";

#Messages to send to students
$grade_message = "Your grade: ";
$too_many_message = "Your latest submission was not recorded because you have already submitted $max_submissions times.\n Had you submitted few enough times, your grade would have been: \n";
$wrong_file_message = "You did not submit the correct files. Please submit @expected_files. You have not used up a submission.";



#Compiles a java file with a given class path.  Returns STDERR
sub java_compile {
	my($class_path, $file) = @_;
	my($errors);
	
	#Compile $file using $classPath
	print "...Compiling $file with class path: $class_path\n";
	$errors = `javac -cp $class_path $file 2>&1`;
	
	print "...ERRORS: $errors\n";
	return $errors;
}

#Runs a java class in a given class path, returns STDOUT
sub java_run {
	my ($class_path, $class, $heredoc ) = @_;
	my ($output );
	
	print "...Running $class with class path: $class_path\n";
	$output = `java -cp $class_path $class  >&1 <<END\n $heredoc \nEND`;
	
	return $output;
}

#Grades, assigns $points if the output of the program is exactly (chomped) $expect
sub grade_equals {
	my($submission, $test_name, $grade_report, $input, $expect, $points) = @_;
	my($test_errors, $score );
	
	print "\nTesting simple $test_name at $submission:\n";
	print "... Copying $test_name.java into submission directory\n";
	
	#Copy test class $test_name.java to user directory $user_dir
	`cp $test_path$test_name.java $submission`;
	
	#Compile the test class, and store any errorw
	$test_errors = java_compile($submission, $submission.$test_name.".java");

	#If there were compile errors, assign a score of 0 and append the errors to the email buffer
	if ( length($test_errors) != 0 )
	{
		$score =  0;
		$EMAIL_BUFFER = $EMAIL_BUFFER."\n Build Errors for $test_name:\n".$test_errors;

	}
	else {
		#Run test that we compiled
		my $output = java_run( $submission, $test_name, $input );
		
		$expect =~ s/^\s+//;
		$expect =~ s/\s+$//;
	
		$output =~ s/^\s+//;
		$output =~ s/\s+$//;
			
		
		print("Program outputs:\n$output");

		if( $expect eq $output ) {
			print( "Output matches\n$expect");
			$score = $points; 
		}
		else {
			print("Output does not exactly match\n$expect");
			$score = 0;
		}
	}

	#Clean up
	print "... Cleaning up\n";
	`rm -f $submission$test_name.* $submission*.class $test_name.txt`;
	
	print "score: $score\n";	
	#Append this test's score onto the grade report and return the grade report
	$grade_report = $grade_report.$score.', ';
	$SCORE_SUM += int($score);
	return $grade_report;
}



#Runs the test entitled $test_name(.java) on the submissions.
#1.) copies the test file to the submissions directory.
#2.) compiles the test.  If there are build errors, assigns a grade of 0
#3.) runs the test. The test is expected to write the score to $test_name.txt 
#4.) Appends the score for this test onto the grade sheet passed to this subroutin
#5.) removes $test_name.* and *.class from the submission directory
#6.) returns the grade sheet
sub grade_simple {
	my($submission, $test_name, $grade_report, $input) = @_;
	my($test_errors, $score );
	
	print "\nTesting simple $test_name at $submission:\n";
	print "... Copying $test_name.java into submission directory\n";
	
	#Copy test class $test_name.java to user directory $user_dir
	`cp $test_path$test_name.java $submission`;
	
	#Compile the test class, and store any errorw
	$test_errors = java_compile($submission, $submission.$test_name.".java");

	#If there were compile errors, assign a score of 0 and append the errors to the email buffer
	if ( length($test_errors) != 0 )
	{
		$score =  0;
		$EMAIL_BUFFER = $EMAIL_BUFFER."\n Build Errors for $test_name:\n".$test_errors;

	}
	else {
		#Run test that we compiled
		my $output = java_run( $submission, $test_name, $input );
		
		if ( -e $test_name.".txt" ) {
			#Fetch the score
			$score = `cat $test_name.txt`;
			#Remove newlines, if any
			chomp($score);
		}
		else
		{
			$score = 0;
		}

	}

	#Clean up
	print "... Cleaning up\n";
	`rm -f $submission$test_name.* $submission*.class $test_name.txt`;
	
	print "score: $score\n";	
	#Append this test's score onto the grade report and return the grade report
	$grade_report = $grade_report.$score.', ';
	$SCORE_SUM += int($score);
	return $grade_report;
}

#Grades a submission, and checks to see if $expected is contained in the output
#Assigns 0 points if the test does not compile, or of $expected does not appear in the output
sub grade_expect {
	my( $submission, $test_name, $grade_report, $input, $expected, $num_lines, $points ) = @_;
	my($test_errors, $score, $output, $output_count);
	
	print "\nTesting user interaction $test_name at $submission:\n";
	print "... Copying $test_name.java into submission directory\n";
	
	#Copy test class $test_name.java to user directory $user_dir
	`cp $test_path$test_name.java $submission`;
	
	#Compile the test class, and store any errorw
	$test_errors = java_compile($submission, $submission.$test_name.".java");

	#If there were compile errors, assign a score of 0 and append the errors to the email buffer
	if ( length($test_errors) != 0 )
	{
		$score =  0;
		$EMAIL_BUFFER = $EMAIL_BUFFER."\n Build Errors for $test_name:\n".$test_errors;

	}
	else {
		#Run test that we compiled
		$output = java_run( $submission, $test_name, $input );
		
		print $output;
		$output_count = `echo \'$output\' | grep \'$expected\' | wc -l >&1`;
		
		#Remove the temporary file
		`rm -f tmp.txt`;
		
		#Remove newlines, and trim whitespace
		chomp($output_count);
		$output_count =~ s/^\s+//;
		$output_count =~ s/\s+$//;
		
		#If we find the desired output at least once, give full credit
		if ($output_count eq $num_lines ) { 
			print "Expected value \"$expected\" found\n";
			$score = $points;
		}

		else { #Otherwise, assign a grade of 0 
			print "Expected value \"$expected\" not found";
			$score = 0;
			}
	}

	#Clean up
	print "... Cleaning up\n";
	`rm -f $submission$test_name.* $submission*.class $test_name.txt`;
	print "score: $score\n";	
	
	#Append this test's score onto the grade report and return the grade report
	$grade_report = $grade_report.$score.', ';
	
	$SCORE_SUM += int($score);

	return $grade_report;
}

#Returns 1 if the submission contains $expected_file.  Otherwise returns 0.
#Marks the submission as graded, if it is invalid
sub is_valid_submission {
	my($submission) = @_;
	
	
	foreach(@expected_files) {
		if ( !(-e $submission.$_) ) {
			print "Marking $submission as invalid file, and graded\n";
			system("touch $submission"."graded.txt");
			system("touch $submission"."invalid.txt");
			return 0;
		}
	}
	
	return 1;
}

#Returns 1 if the submission has already been graded, otherwise returns 0
sub is_already_graded {
	my( $submission ) = @_;
	if ( -e $submission."graded.txt") {
		return 1;
	} 
	return 0;
}

#Sends an email
sub send_email {
	my( $email_address, $body ) = @_;

	print("Sending e-mail\n");
	`echo \'$body\' | mutt -s \"$project_name\" $email_address`;
}

#Writes a grade to the class grade sheet, as well as individual grade file in the submission directory
sub write_grade {
	my( $submission, $user_name, $grade_report , $write_class_grade_sheet) = @_;
	

	print "Writing grade to class grade sheet\n";
	if( $write_class_grade_sheet) {	
		#Write grade to class grade sheet
		open(CLASS_GRADES, ">>", $grade_file);
		print CLASS_GRADES "$grade_report\n";
		close(CLASS_GRADES);
	}

	#Write grade to submission folder
	print "Writing grade to submission grade sheet\n";
	open(STUDENT_GRADE, ">>", $submission."grade.csv");
	print STUDENT_GRADE "$grade_report\n";
	close(STUDENT_GRADE);

}




#Grades a submission
#Writes the grade to a grade file in the submission directory
#If $write_class_grade_sheet = 1, append the the score to the class grade sheet
#Appends grade report to email buffer
sub grade_submission {
	my ($submission, $user_name, $write_class_grade_sheet) = @_;
	my ( $date, $grade_report, $roster_info );

	print "\n\nGrading $submission, with user name: $user_name\n";
   	print "Marking $submission as graded\n";
	system("touch $submission"."graded.txt");
	
	$SCORE_SUM = 0;
	$date = `date +%D\\ %H:%M`;
	chomp( $date );
	
	$roster_info = `cat $class_roster | grep $user_name`;
	chomp($roster_info);
	
	$grade_report=$roster_info.", ".$date.", ";

	#grade_simple syntax:
	#grade_simple( Submission, Test Name, Grade Report, (Input to program) )

	#grade_Number of lines that should match, expect syntax:
	#grade_expect( Submission, Test Name, Grade Report, Input, Expected Output, Number of lines that should match, Points for Test)
	
	#BEGIN GRADE CODE
	
	$grade_report = grade_simple($submission, "Test1a", $grade_report);
	
	$grade_report = grade_simple($submission, "Test2a", $grade_report);
	$grade_report = grade_simple($submission, "Test2b", $grade_report);
	$grade_report = grade_simple($submission, "Test2c", $grade_report);
	
	$grade_report = grade_simple($submission, "Test3a", $grade_report);
	$grade_report = grade_simple($submission, "Test3b", $grade_report);
	$grade_report = grade_simple($submission, "Test3c", $grade_report);
	
	$grade_report = grade_simple($submission, "Test4a", $grade_report);
	$grade_report = grade_simple($submission, "Test4b", $grade_report);
	$grade_report = grade_simple($submission, "Test4c", $grade_report);
	
	$grade_report = grade_simple($submission, "Test5a", $grade_report);
	$grade_report = grade_simple($submission, "Test5b", $grade_report);
	$grade_report = grade_simple($submission, "Test5c", $grade_report);
	
	$grade_report = grade_simple($submission, "Test6a", $grade_report);
	$grade_report = grade_simple($submission, "Test6b", $grade_report);
	$grade_report = grade_simple($submission, "Test6c", $grade_report);
	
	
	$grade_report = grade_simple($submission, "Test7a", $grade_report);
	$grade_report = grade_simple($submission, "Test7b", $grade_report);
	
	$grade_report = grade_simple($submission, "Test8a", $grade_report);
	$grade_report = grade_simple($submission, "Test8b", $grade_report);
	
	$grade_report = grade_simple($submission, "Test9a", $grade_report);
	$grade_report = grade_simple($submission, "Test9b", $grade_report);
	
	
	#END GRADE CODE

	$grade_report = $grade_report.$SCORE_SUM.", ";
	print "GRADE_REPORT: $grade_report\n";

	#Write the grade to the grade sheet, and put a copy in the submission directory
	write_grade( $submission, $user_name, $grade_report, $write_class_grade_sheet );
	
	$EMAIL_BUFFER = $EMAIL_BUFFER."\n\n\n".$grade_message." ".$grade_report;
}

#Appends a given log to the log file
sub append_log {
	my( $entry ) = @_;
	open(LOG, ">>", $log_file);
	print LOG $entry.'\n';
	close (LOG);
}


#Returns 0 if the user has submitted a valid submission fewer than $max_submissions times.  Otherwise returns 1.
#Marks the submission as graded if the user has submitted too many times
sub too_many_submissions {
	my( $submission, $user_name ) = @_;
	my( $num_submissions );

	$num_submissions = `cat $grade_file | grep $user_name | wc -l >&1`;
	
	#Remove newlines, and trim whitespace
	chomp($num_submissions);
	$num_submissions =~ s/^\s+//;
	$num_submissions =~ s/\s+$//;


	if ( $num_submissions lt $max_submissions ) {
		return 0;
	}
	
	print "Marking $submission as too many submissions, and graded\n";
	system("touch $submission"."graded.txt");
	system("touch $submission"."too_many.txt");
	
	return 1;
	
}

#Main grading loop
#Grades every submission in $submission_path in chronological order (oldest to newest)
#Terminates
sub grade_loop {
	my( $user_name, $submission );
	
	
	#For each file or directory in $submission_path from oldest to newest
	foreach(`ls -tr $submission_path`)
	{
		
		chomp($_); #Clean up name
		
		if(-d $submission_path.$_ ) # Is it a directory?
   		{
			#Clear email buffer
			$EMAIL_BUFFER = '';
			#Path to the submission to be evaluated
			$submission = $submission_path.$_.'/';
			
			#Get the ENGR username from the directory name, removing suffixes
			$user_name = $_;
			$user_name =~ s/([a-z0-9]+)\..*/$1/;
			
			#If the submission has not already been graded
			if ( not is_already_graded($submission) ) {
				
				#If the submission is valid, grade it
				if( is_valid_submission($submission) ) {
					
					#If the user has not submitted too many times
					if ( not too_many_submissions($submission, $user_name) ) {
						grade_submission($submission, $user_name, 1);
					}
					else {
						#Too many submissions, skip and email the user
						$EMAIL_BUFFER = $EMAIL_BUFFER.$too_many_message;
						grade_submission($submission, $user_name, 0);
					}
				}
				else {
					#The submission is invalid, skip and email the user	
					print "Skipping $submission with user name: $user_name (invalid submission)\n";
					$EMAIL_BUFFER = $EMAIL_BUFFER. $wrong_file_message;
				}
				
			
				#Email the buffer to the user
				send_email("$user_name\@engr.orst.edu", $EMAIL_BUFFER );
				
			}
			else {
				#Already graded (or marked as invalid), skip silently
				print "Skipping $submission with user name: $user_name (already graded!)\n";
			}
			
		}
	}
}

#Runs perpetually, sleeping for some interval after each grade loop
while(1)
{
	my($date);
	print "\nBEGIN GRADING LOOP\n\n\n";
	
	grade_loop();
	
	$date = `date +%D\\ %H:%M`;
	chomp( $date );
	
	print "\n\n\nSLEEPING FOR $sleep_time SECONDS \@ $date\n\n\n";
	sleep($sleep_time);
}

#print( triangle_reverse(5));
