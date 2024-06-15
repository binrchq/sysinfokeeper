package GlabelData;

# gptid/c5e940f1-5ce2-11e6-9eeb-d05099ac4dc2     N/A  ada0p1
#                                 gpt/efiesp     N/A  ada0p2
sub get {
	eval $start if $b_log;
	my $gptid = $_[0];
	set() if !$loaded{'glabel'};
	return if !@glabel || !$gptid;
	my $dev_id = '';
	foreach (@glabel){
		my @temp = split(/\s+/, $_);
		my $gptid_trimmed = $gptid;
		# slice off s[0-9] from end in case they use slice syntax
		$gptid_trimmed =~ s/s[0-9]+$//;
		if (defined $temp[0] && ($temp[0] eq $gptid || $temp[0] eq $gptid_trimmed)){
			$dev_id = $temp[2];
			last;
		}
	}
	$dev_id ||= $gptid; # no match? return full string
	eval $end if $b_log;
	return $dev_id;
}

sub set {
	eval $start if $b_log;
	$loaded{'glabel'} = 1;
	if (my $path = main::check_program('glabel')){
		@glabel = main::grabber("$path status 2>/dev/null",'','strip');
	}
	main::log_data('dump','@glabel:with Headers',\@glabel) if $b_log;
	# get rid of first header line
	shift @glabel;
	eval $end if $b_log;
}
}

sub get_hostname {
	eval $start if $b_log;
	my $hostname = '';
	if ($ENV{'HOSTNAME'}){
		$hostname = $ENV{'HOSTNAME'};
	}
	elsif (!$bsd_type && -r "/proc/sys/kernel/hostname"){
		$hostname = reader('/proc/sys/kernel/hostname','',0);
	}
	# puppy removed this from core modules, sigh
	# this is faster than subshell of hostname
	elsif (check_perl_module('Sys::Hostname')){
		Sys::Hostname->import;
		$hostname = Sys::Hostname::hostname();
	}
	elsif (my $program = check_program('hostname')){
		$hostname = (grabber("$program 2>/dev/null"))[0];
	}
	$hostname ||= 'N/A';
	eval $end if $b_log;
	return $hostname;
}

## InitData
{