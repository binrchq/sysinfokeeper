package KernelParameters;

sub get {
	eval $start if $b_log;
	my ($parameters);
	if (my $file = $system_files{'proc-cmdline'}){
		$parameters = parameters_linux($file);
	}
	elsif ($bsd_type){
		$parameters = parameters_bsd();
	}
	eval $end if $b_log;
	return $parameters;
}

sub parameters_linux {
	eval $start if $b_log;
	my ($file) = @_;
	# unrooted android may have file only root readable
	my $line = main::reader($file,'',0) if -r $file;
	$line =~ s/\s\s+/ /g;
	eval $end if $b_log;
	return $line;
}

sub parameters_bsd {
	eval $start if $b_log;
	my ($parameters);
	eval $end if $b_log;
	return $parameters;
}
}

## LsblkData: public methods: set(), get()
{