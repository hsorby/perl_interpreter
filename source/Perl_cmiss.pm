#*******************************************************************************
#FILE : Perl_cmiss.pm
#
#LAST MODIFIED : 22 August 2000
#
#DESCRIPTION :
#With perl_interpreter.c provides an interface between cmiss and a 
#Perl interpreter.
#===============================================================================

package Perl_cmiss;

$VERSION = '0.01';
bootstrap Perl_cmiss $VERSION;

# Preloaded methods go here.

#Using a hash so that the strategy for action could be placed with
#the word.  For now only one action.
my %keywords;
my @command_list = ();
my $block_count = 0;
my $block_required = 0;
my $echo_commands = 0;
my $cmiss_debug = 0;

sub register_keyword
  {
	 my $word = shift;
	 
	 #print \"register $word\\n\";
	 
	 $keywords{$word} = 1;
  }

sub call_command
  {
	 local $command = shift;
	 {
		package main;
		*{main::cmiss} = \&{Perl_cmiss::cmiss};
		# Catch all warnings as errors */
		local $SIG{__WARN__} = sub { die $_[0] };
		eval ($Perl_cmiss::command);
	 }
  }

sub execute_command
  {
	 my $command = shift;
	 my $command2 = $command;
	 $command2 =~ s%'%\\'%g;
	 $command2 = "print '>  $command2' . \"\\n\";";
	 my $token = "";
	 my $part_token;
	 my $token2;
	 my $lc_token;
	 my $match_string = join ("|", keys %keywords);
#	 my @tokens = &parse_line('\\s*[\\{\\}\\(\\)]\\s*', \"delimiters\", $command);
#	 my @tokens; push (@tokens, $command);
	 my @tokens = ();
	 my $extracted;
	 my $lc_command;
	 my $continue;
	 my $reduced_command;
	 my $print_command_after = 0;
	 my $is_perl_token;
	 my $simple_perl;

	 $simple_perl = 0;
	 while ($command ne "")
		{
		  $lc_command = lc ($command);
		  if ($cmiss_debug)
			 {
				print "$command   ";
			 }
		  if ($command =~ s%^(\s+)%%)
			 {
				if ($cmiss_debug)
				  {
					 print "space: $1\n";
				  }
				$token = $token . $1;
			 }
		  elsif ($command =~ s%^(#.*)%%)
			 {
			  if ($cmiss_debug)
			    {
					print "comment: $1\n";
				 }
			  if ($simple_perl && (!$block_required) && (! ($token =~ m/;\s*$/)))
			  {
				 $token = $token . ";";
			  }
			  if ($token ne "")
			  {
				 push(@tokens, $token);
			  }
			  $token = "";
			 }
		  else
			 {
				$simple_perl = 0;
				if ($command =~ s%^({)%%)
				  {
					 if ($cmiss_debug)
						{
						  print "open bracket: $1\n";
						}
					 if ($token ne "")
						{
						  push(@tokens, $token);
						}
					 $block_required = 0;
					 $block_count++;
					 $print_command_after = 1;
					 $token = "";
					 push(@tokens, $1);
				  }
				elsif ($command =~ s%^(})%%)
				  {
					 if ($cmiss_debug)
						{
						  print "close bracket: $1\n";
						}
					 if ($token ne "")
						{
						  push(@tokens, $token);
						}
					 if ($block_count > 0)
						{
						  $block_count--;
						}
					 $print_command_after = 0;
					 $token = "";
					 push(@tokens, $1);
				  }
				elsif ($command =~ s%^(if|while|unless|until|for|foreach|elsif|else|continue|sub)%%)
				  {
					 if ($cmiss_debug)
						{
						  print "control keyword: $1\n";
						}
					 $token = $token . $1;
					 $block_required = 1;
				  }
				elsif ($lc_command =~ m/^itp/)
				  {
					 if ($lc_command =~ m/^itp\s+ass\w*\s+blo\w*\s+clo\w*/)
						{
						  if ($block_required || $block_count)
							 {
								$block_required = 0;
								$block_count = 0;
								@command_list = ();
								die ("itp assert blocks closed failed");
							 }
						}
					 elsif ($lc_command =~ m/^itp\s+set\s+echo\s*(\w*)/)
						{
						  if ($1 =~ m/on/)
							 {
								$echo_commands = 1;
							 }
						  elsif ($1 =~ m/off/)
							 {
								$echo_commands = 0;
							 }
						  else
							 {
								$echo_commands = ! $echo_commands;
							 }
						}
					 elsif ($lc_command =~ m/^itp\s+set\s+debug\s*(\w*)/)
						{
						  if ($1 =~ m/on/)
							 {
								$cmiss_debug = 1;
							 }
						  elsif ($1 =~ m/off/)
							 {
								$cmiss_debug = 0;
							 }
						  else
							 {
								$cmiss_debug = ! $cmiss_debug;
							 }
						}
					 else
						{
						  die ("Unknown itp environment command");
						}
					 $command =~ s/^([^}#]*)//;
					 if ($cmiss_debug)
						{
						  print "itp: $1\n";
						}
				  }
				else
				  {
					 $continue = 1;
					 if ($token =~ m/^\s*$/)
						{
						  if (($lc_command =~ m/^(?:$match_string)/)
								|| ($lc_command =~ m/^q$/)
								|| ($lc_command =~ m/^\?+$/))
							 {
								if ($cmiss_debug)
								  {
									 $token = $token . "(\$return_code = Perl_cmiss::cmiss(\"";
								  }
								else
								  {
									 $token = $token . "(Perl_cmiss::cmiss(\"";
								  }
								$part_token = "";
								$token2 = "";
								$is_perl_token = 1;
								$is_simple_token = 1;
								while (($command ne "") && !($command =~ m/(^[}	#])/))
								  {
									 if ($cmiss_debug)
										{
										  print "cmiss $command   ";
										}
									 if ($command =~ s%^([\s;]+)%%)
										{
										  if ($cmiss_debug)
											 {
												print "cmiss space: $1\n";
											 }
										  if (!$is_simple_token && $is_perl_token)
											 {
												# Let Perl parse this into a string
												$token = $token . "\\\"\"." . "join(\",\",$part_token).\"\\\"$1";
											 }
										  else
											 {
												# Just add it in normally 
												# Escape \\ and " characters
												$part_token =~ s/\\/\\\\/g;
												$part_token =~ s/\"/\\\"/g;
												$token = $token . $part_token . $1;
											 }
										  $token2 = $token2 . $part_token . $1;
										  $is_perl_token = 1;
										  $is_simple_token = 1;
										  $part_token = "";
										}
									 elsif (($part_token eq "") && ($command =~ s%^(\?|[\-]?[.,0-9:]+)%%))
										{
										  if ($cmiss_debug)
											 {
												print "cmiss number/operator: $1\n";
											 }
										  $part_token = $part_token . $1;
										}
									 elsif ($command =~ s%^([.,0-9:]+)%%)
										{
										  if ($cmiss_debug)
											 {
												print "cmiss number/operator: $1\n";
											 }
										  $part_token = $part_token . $1;
										}
									 elsif ($command =~ s%^([+\-*=/\\<>!()?])%%)
										{
										  if ($cmiss_debug)
											 {
												print "cmiss perl number/operator: $1\n";
											 }
										  $part_token = $part_token . $1;
										  $is_simple_token = 0;
										}
									 elsif ($command =~ s%^(\w+\()%%)
										{
										  if ($cmiss_debug)
											 {
												print "cmiss function: $1\n";
											 }
										  $part_token = $part_token . $1;
										  $is_simple_token = 0;
										}
									 else
										{
										  $is_simple_token = 0;
										  ($extracted, $reduced_command) = 
											 Text::Balanced::extract_variable($command);
										  if ($extracted)
											 {
												$command = $reduced_command;
												$part_token = $part_token . $extracted;
												if ($cmiss_debug)
												  {
													 print "cmiss variable: $extracted\n";
												  }
											 }
										  else
											 {
												($extracted, $reduced_command) =
												  Text::Balanced::extract_delimited($command, '\'"`');
												if ($extracted)
												  {
													 $command = $reduced_command;
													 #Escape " and \ characters except for the start and end ones
													 $extracted =~ s/(?<=.)\\(?=.)/\\\\/g;
													 $extracted =~ s/(?<=.)\"(?=.)/\\\"/g;
													 $part_token = $part_token . $extracted;
													 if ($cmiss_debug)
														{
														  print "cmiss delimited: $extracted\n";
														}
												  }
												else
												  {
													 if ($cmiss_debug)
														{
														  print "cmiss character: ".substr($command, 0, 1)."\n";
														}
													 $part_token = $part_token . substr($command, 0, 1);
													 $command = substr($command, 1);
													 $is_perl_token = 0;
												  }
											 }
										}
								  }
							  $token2 = $token2 . $part_token;
							  $token2 =~ s/\\/\\\\/g;
							  $token2 =~ s/\"/\\\"/g;
							  if ($cmiss_debug)
							    {
									print "token2 $token2\n";
								 }
							  if (!$is_simple_token && $is_perl_token)
								 {
									# Let Perl parse this into a string
									$token = $token . "\\\"\".join(\",\",$part_token).\"\\\"\")) || die(\"Error in cmiss command \\\"$token2\\\".\\n\");";
								 }
							  else
								 {
									# Just add it in normally 
									# Escape \\ and " characters
									$part_token =~ s/\\/\\\\/g;
									$part_token =~ s/\"/\\\"/g;
									$token = $token . $part_token . "\")) || die(\"Error in cmiss command \\\"$token2\\\".\\n\");";
								 }
							  if ($cmiss_debug)
								 {
									print "cmiss: $token\n";
								 }
							  push(@tokens, $token);
							  $token = "";
						     $continue = 0;
                    }
				    }
				  if ($continue)
					 {
						$simple_perl = 1;
						if ($command =~ s/^(\d+)\s*\.\.\s*(\d+)\s*:\s*(\d+)//)
						  {
							 my $remainder_start = $1 % $3;
							 my $remainder_finish = ($2 - $remainder_start) % $3;
							 my $list_start = ($1 - $remainder_start) / $3;
							 my $list_finish = ($2 - $remainder_start - $remainder_finish)/ $3;
							 my $new_list_operator = "(map {\$_ * $3 + $remainder_start} $list_start..$list_finish)";
							 $token = $token . $new_list_operator;
							 if ($cmiss_debug)
								{
								  print "step sequence: $new_list_operator\n";
								}
						  }
						else
						  {
							 ($extracted, $reduced_command) =
								Text::Balanced::extract_variable($command);
							 if ($extracted)
								{
								  $command = $reduced_command;
								  if ($cmiss_debug)
									 {
										print "variable: $extracted\n";
									 }
								  $token = $token . $extracted;
								}
							 else
								{
								  ($extracted, $reduced_command) =
									 Text::Balanced::extract_quotelike($command);
								  if ($extracted)
									 {
										$command = $reduced_command;
										if ($cmiss_debug)
										  {
											 print "quotelike: $extracted\n";
										  }
										$token = $token . $extracted;
									 }
								  else
									 {
										if ($cmiss_debug)
										  {
											 print "character: " . substr($command, 0, 1) . "\n";
										  }
										$token = $token . substr($command, 0, 1);
										$command = substr($command, 1);
									 }
								}
						  }
					 }
				}
			}
		}
	 if ($token ne "")
		{
		  #Add a semicolon if not already there.
		  if ($simple_perl && (!$block_required) && (! ($token =~ m/;\s*$/)))
			 {
				$token = $token . ";";
			 }
		  push(@tokens, $token);
		}
						  
	$command = join ("", @tokens);
	if ($cmiss_debug)
	  {
		 print "Perl_cmiss::execute_command parsed $command\n";
		 print "Perl_cmiss::execute_command parsed $command2\n";
	  }
	if ($echo_commands && (! $print_command_after))
     {
		 push (@command_list, $command2);
	  }
   push (@command_list, $command);
   if ($echo_commands && $print_command_after)
     {
		 push (@command_list, $command2);
	  }

#	 print \"$block_count $block_required\\n\";

	 if ((!($block_count))&&(!($block_required)))
		{
		  $command = join ("\n", @command_list);
		  #Must reset this before the eval as it may call this function
		  #recursively before returning from this function
		  @command_list = ();
		  call_command($command);
		  if ($@)
			 {
				#Trim the useless line number info if it has been added.
				$@ =~ s/ at \(eval \d+\) line \d+//;
				die("$@\n");
			 }
		  print "";
		}
  }
