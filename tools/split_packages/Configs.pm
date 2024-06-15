package Configs;

sub set {
	my ($b_show) = @_;
	my ($b_files,$key, $val,@config_files);
	# removed legacy kde @$configs test which never worked
	@config_files = (
	qq(/etc/$self_name.conf), 
	qq(/etc/$self_name.d/$self_name.conf), # this was wrong path, but check in case
	qq(/etc/$self_name.conf.d/$self_name.conf),
	qq(/usr/etc/$self_name.conf), 
	qq(/usr/etc/$self_name.conf.d/$self_name.conf),
	qq(/usr/local/etc/$self_name.conf), 
	qq(/usr/local/etc/$self_name.conf.d/$self_name.conf),
	qq($user_config_dir/$self_name.conf)
	);
	# Config files should be passed in an array as a param to this function.
	# Default intended use: global @CONFIGS;
	foreach (@config_files){
		next unless -e $_ && open(my $fh, '<', "$_");
		my $b_configs;
		$b_files = 1;
		print "${line1}Configuration file: $_\n" if $b_show;
		while (<$fh>){
			chomp;
			s/#.*//;
			s/^\s+//;
			s/\s+$//;
			s/'|"//g;
			next unless length;
			($key, $val) = split(/\s*=\s*/, $_, 2);
			next unless length($val);
			$val =~ s/true/1/i; # switch to 1/0 perl boolean
			$val =~ s/false/0/i; # switch to 1/0 perl boolean
			if (!$b_show){
				process_item($key,$val);
			}
			else {
				print $line3 if !$b_configs;
				print "$key=$val\n";
				$b_configs = 1;
			}
			# print "f: $file key: $key val: $val\n";
		}
		close $fh;
		if ($b_show && !$b_configs){
			print "No configuration items found in file.\n";
		}
	}
	return $b_files if $b_show;
}

sub show {
	print "Showing current active/set configurations, by file. Last overrides previous.\n";
	my $b_files = set(1);
	print $line1;
	if ($b_files){
		print "All done! Everything look good? If not, fix it.\n";
	}
	else {
		print "No configuration files found. Is that what you expected?\n";
	}
	exit 0;
}

# note: someone managed to make a config file with corrupted values, so check
# int explicitly, don't assume it was done correctly.
# args: 0: key; 1: value
sub process_item {
	my ($key,$val) = @_;
	
	## UTILITIES ##
	if ($key eq 'ALLOW_UPDATE' || $key eq 'B_ALLOW_UPDATE'){
		$use{'update'} = $val if main::is_int($val)}
	elsif ($key eq 'ALLOW_WEATHER' || $key eq 'B_ALLOW_WEATHER'){
		$use{'weather'} = $val if main::is_int($val)}
	elsif ($key eq 'CPU_SLEEP'){
		$cpu_sleep = $val if main::is_numeric($val)}
	elsif ($key eq 'DL_TIMEOUT'){
		$dl_timeout = $val if main::is_int($val)}
	elsif ($key eq 'DOWNLOADER'){
		if ($val =~ /^(curl|fetch|ftp|perl|wget)$/){
			# this dumps all the other data and resets %dl for only the
			# desired downloader.
			$val = main::set_perl_downloader($val);
			%dl = ('dl' => $val, $val => 1);
		}}
	elsif ($key eq 'FAKE_DATA_DIR'){
		$fake_data_dir = $val}
	elsif ($key eq 'FILTER_STRING'){
		$filter_string = $val}
	elsif ($key eq 'LANGUAGE'){
		$language = $val if $val =~ /^(en)$/}
	elsif ($key eq 'LIMIT'){
		$limit = $val if main::is_int($val)}
	elsif ($key eq 'OUTPUT_TYPE'){
		$output_type = $val if $val =~ /^(json|screen|xml)$/}
	elsif ($key eq 'NO_DIG'){
		$force{'no-dig'} = $val if main::is_int($val)}
	elsif ($key eq 'NO_DOAS'){
		$force{'no-doas'} = $val if main::is_int($val)}
	elsif ($key eq 'NO_HTML_WAN'){
		$force{'no-html-wan'} = $val if main::is_int($val)}
	elsif ($key eq 'NO_SUDO'){
		$force{'no-sudo'} = $val if main::is_int($val)}
	elsif ($key eq 'PARTITION_SORT'){
		if ($val =~ /^(dev-base|fs|id|label|percent-used|size|uuid|used)$/){
			$show{'partition-sort'} = $val;
		}}
	elsif ($key eq 'PS_COUNT'){
		$ps_count = $val if main::is_int($val) }
	elsif ($key eq 'SENSORS_CPU_NO'){
		$sensors_cpu_nu = $val if main::is_int($val)}
	elsif ($key eq 'SENSORS_EXCLUDE'){
		@sensors_exclude = split(/\s*,\s*/, $val) if $val}
	elsif ($key eq 'SENSORS_USE'){
		@sensors_use = split(/\s*,\s*/, $val) if $val}
	elsif ($key eq 'SHOW_HOST' || $key eq 'B_SHOW_HOST'){
		if (main::is_int($val)){
			$show{'host'} = $val;
			$show{'no-host'} = 1 if !$show{'host'};
		}
	}
	elsif ($key eq 'USB_SYS'){
		$force{'usb-sys'} = $val if main::is_int($val)}
	elsif ($key eq 'WAN_IP_URL'){
		if ($val =~ /^(ht|f)tp[s]?:\//i){
			$wan_url = $val;
			$force{'no-dig'} = 1;
		}
	}
	elsif ($key eq 'WEATHER_SOURCE'){
		$weather_source = $val if main::is_int($val)}
	elsif ($key eq 'WEATHER_UNIT'){ 
		$val = lc($val) if $val;
		if ($val && $val =~ /^(c|f|cf|fc|i|m|im|mi)$/){
			my %units = ('c'=>'m','f'=>'i','cf'=>'mi','fc'=>'im');
			$val = $units{$val} if defined $units{$val};
			$weather_unit = $val;
		}
	}
	
	## COLORS/SEP ##
	elsif ($key eq 'CONSOLE_COLOR_SCHEME'){
		$colors{'console'} = $val if main::is_int($val)}
	elsif ($key eq 'GLOBAL_COLOR_SCHEME'){
		$colors{'global'} = $val if main::is_int($val)}
	elsif ($key eq 'IRC_COLOR_SCHEME'){
		$colors{'irc-gui'} = $val if main::is_int($val)}
	elsif ($key eq 'IRC_CONS_COLOR_SCHEME'){
		$colors{'irc-console'} = $val if main::is_int($val)}
	elsif ($key eq 'IRC_X_TERM_COLOR_SCHEME'){
		$colors{'irc-virt-term'} = $val if main::is_int($val)}
	elsif ($key eq 'VIRT_TERM_COLOR_SCHEME'){
		$colors{'virt-term'} = $val if main::is_int($val)}
	# note: not using the old short SEP1/SEP2
	elsif ($key eq 'SEP1_IRC'){
		$sep{'s1-irc'} = $val}
	elsif ($key eq 'SEP1_CONSOLE'){
		$sep{'s1-console'} = $val}
	elsif ($key eq 'SEP2_IRC'){
		$sep{'s2-irc'} = $val}
	elsif ($key eq 'SEP2_CONSOLE'){
		$sep{'s2-console'} = $val}
		
	## SIZES ##
	elsif ($key eq 'COLS_MAX_CONSOLE'){
		$size{'console'} = $val if main::is_int($val)}
	elsif ($key eq 'COLS_MAX_IRC'){
		$size{'irc'} = $val if main::is_int($val)}
	elsif ($key eq 'COLS_MAX_NO_DISPLAY'){
		$size{'no-display'} = $val if main::is_int($val)}
	elsif ($key eq 'INDENT'){
		$size{'indent'} = $val if main::is_int($val)}
	elsif ($key eq 'INDENTS'){
		$filter_string = $val if main::is_int($val)}
	elsif ($key eq 'LINES_MAX'){
		if ($val =~ /^-?\d+$/ && $val >= -1){
			if ($val == 0){
				$size{'max-lines'} = $size{'term-lines'};}
			elsif ($val == -1){
				$use{'output-block'} = 1;}
			else {
				$size{'max-lines'} = $val;}
		}}
	elsif ($key eq 'MAX_WRAP' || $key eq 'WRAP_MAX' || $key eq 'INDENT_MIN'){
		$size{'max-wrap'} = $val if main::is_int($val)}
	#  print "mc: key: $key val: $val\n";
	# print Dumper (keys %size) . "\n";
}

sub check_file {
	$user_config_file = "$user_config_dir/$self_name.conf";
	if (! -f $user_config_file){
		open(my $fh, '>', $user_config_file) or 
		 main::error_handler('create', $user_config_file, $!);
	}
}
}

#### -------------------------------------------------------------------
#### DEBUGGERS
#### -------------------------------------------------------------------

# called in the initial -@ 10 program args setting so we can get logging 
# as soon as possible # will have max 3 files, inxi.log, inxi.1.log, 
# inxi.2.log
sub begin_logging {
	return 1 if $fh_l; # if we want to start logging for testing before options
	my $log_file_2 = "$user_data_dir/$self_name.1.log";
	my $log_file_3 = "$user_data_dir/$self_name.2.log";
	my $data = '';
	$end = 'main::log_data("fe", (caller(1))[3], "");';
	$start = 'main::log_data("fs", (caller(1))[3], \@_);';
	#$t3 = tv_interval ($t0, [gettimeofday]);
	$t3 = eval 'Time::HiRes::tv_interval (\@t0, [Time::HiRes::gettimeofday()]);' if $b_hires;
	# print Dumper $@;
	my $now = strftime "%Y-%m-%d %H:%M:%S", localtime;
	return if $debugger{'timers'};
	# do the rotation if logfile exists
	if (-f $log_file){
		# copy if present second to third
		if (-f $log_file_2){
			rename $log_file_2, $log_file_3 or error_handler('rename', "$log_file_2 -> $log_file_3", "$!");
		}
		# then copy initial to second
		rename $log_file, $log_file_2 or error_handler('rename', "$log_file -> $log_file_2", "$!");
	}
	# now create the logfile
	# print "Opening log file for reading: $log_file\n";
	open($fh_l, '>', $log_file) or error_handler(4, $log_file, "$!");
	# and echo the start data
	$data = $line2;
	$data .= "START $self_name LOGGING:\n";
	$data .= "NOTE: HiRes timer not available.\n" if !$b_hires;
	$data .= "$now\n";
	$data .= "Elapsed since start: $t3\n";
	$data .= "n: $self_name v: $self_version p: $self_patch d: $self_date\n";
	$data .= '@paths:' . joiner(\@paths, '::', 'unset') . "\n";
	$data .= $line2;
	
	print $fh_l $data;
}

# NOTE: no logging available until get_parameters is run, since that's what 
# sets logging # in order to trigger earlier logging manually set $b_log
# to true in top variables.
# args: 0: type [fs|fe|cat|dump|raw]; 1: function name OR data to log; 
# [2: function args OR hash/array ref]
sub log_data {
	return if !$b_log;
	my ($one, $two, $three) = @_;
	my ($args,$data,$timer) = ('','','');
	my $spacer = '   ';
	# print "1: $one 2: $two 3: $three\n";
	if ($one eq 'fs'){
		if (ref $three eq 'ARRAY'){
			# print Data::Dumper::Dumper $three;
			$args = "\n${spacer}Args: " . joiner($three, '; ', 'unset');
		}
		else {
			$args = "\n${spacer}Args: None";
		}
		# $t1 = [gettimeofday];
		#$t3 = tv_interval ($t0, [gettimeofday]);
		$t3 = eval 'Time::HiRes::tv_interval(\@t0, [Time::HiRes::gettimeofday()])' if $b_hires;
		# print Dumper $@;
		$data = "Start: Function: $two$args\n${spacer}Elapsed: $t3\n";
		$spacer='';
		$timer = $data if $debugger{'timers'};
	}
	elsif ($one eq 'fe'){
		# print 'timer:', Time::HiRes::tv_interval(\@t0, [Time::HiRes::gettimeofday()]),"\n";
		#$t3 = tv_interval ($t0, [gettimeofday]);
		eval '$t3 = Time::HiRes::tv_interval(\@t0, [Time::HiRes::gettimeofday()])' if $b_hires;
		# print Dumper $t3;
		$data = "${spacer}Elapsed: $t3\nEnd: Function: $two\n";
		$spacer='';
		$timer = $data if $debugger{'timers'};
	}
	elsif ($one eq 'cat'){
		if ($b_log_full){
			foreach my $file ($two){
				my $contents = do { local(@ARGV, $/) = $file; <> }; # or: qx(cat $file)
				$data = "$data${line3}Full file data: $file\n\n$contents\n$line3\n";
			}
			$spacer='';
		}
	}
	elsif ($one eq 'cmd'){
		$data = "Command: $two\n";
		$data .= qx($two);
	}
	elsif ($one eq 'data'){
		$data = "$two\n";
	}
	elsif ($one eq 'dump'){
		$data = "$two:\n";
		if (ref $three eq 'HASH'){
			$data .= Data::Dumper::Dumper $three;
		}
		elsif (ref $three eq 'ARRAY'){
			# print Data::Dumper::Dumper $three;
			$data .= Data::Dumper::Dumper $three;
		}
		else {
			$data .= Data::Dumper::Dumper $three;
		}
		$data .= "\n";
		# print $data;
	}
	elsif ($one eq 'raw'){
		if ($b_log_full){
			$data = "\n${line3}Raw System Data:\n\n$two\n$line3";
			$spacer='';
		}
	}
	else {
		$data = "$two\n";
	}
	if ($debugger{'timers'}){
		print $timer if $timer;
	}
	# print "d: $data";
	elsif ($data){
		print $fh_l "$spacer$data";
	}
}

sub set_debugger {
	user_debug_test_1() if $debugger{'test-1'};
	if ($debugger{'level'} >= 20){
		error_handler('not-in-irc', 'debug data generator') if $b_irc;
		my $option = ($debugger{'level'} > 22) ? 'main-full' : 'main';
		$debugger{'gz'} = 1 if ($debugger{'level'} == 22 || $debugger{'level'} == 24);
		my $ob_sys = SystemDebugger->new($option);
		$ob_sys->run_debugger();
		$ob_sys->upload_file($ftp_alt) if $debugger{'level'} > 20;
		exit 0;
	}
	elsif ($debugger{'level'} >= 10 && $debugger{'level'} <= 12){
		$b_log = 1;
		if ($debugger{'level'} == 11){
			$b_log_full = 1;
		}
		elsif ($debugger{'level'} == 12){
			$b_log_colors = 1;
		}
		begin_logging();
	}
	elsif ($debugger{'level'} <= 3){
		if ($debugger{'level'} == 3){
			$b_log = 1;
			$debugger{'timers'} = 1;
			begin_logging();
		}
		else {
			$end = '';
			$start = '';
		}
	}
}

## SystemDebugger
{