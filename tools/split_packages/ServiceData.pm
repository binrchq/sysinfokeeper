package ServiceData;
my ($key,$service,$type);

sub get {
	eval $start if $b_log;
	($type,$service) = @_;
	my $value;
	set() if !$loaded{'service-tool'};
	$key = (keys %service_tool)[0] if %service_tool;
	if ($key){
		if ($type eq 'status'){
			$value = process_status();
		}
		elsif ($type eq 'tool'){
			$value = $service_tool{$key}->[1];
		}
	}
	eval $end if $b_log;
	return $value;
}

sub process_status {
	eval $start if $b_log;
	my ($cmd,$status,@data);
	my ($result,$value) = ('','');
	my %translate = (
	'active' => 'running',
	'down' => 'stopped',
	'fail' => 'not found', 
	'failed' => 'not found', 
	'inactive' => 'stopped',
	'ok' => 'running',
	'not running' => 'stopped',
	'run' => 'running',
	'started' => 'running',
	);
	if ($key eq 'systemctl'){
		$cmd = "$service_tool{$key}->[0] status $service";
	}
	# can be /etc/init.d or /etc/rc.d; ghostbsd/gentoo have this
	elsif ($key eq 'rc-service'){
		$cmd = "$service_tool{$key}->[0] $service status";
	}
	elsif ($key eq 'rcctl'){
		$cmd = "$service_tool{$key}->[0] check $service";
	}
	# dragonfly/netbsd/freebsd have this. We prefer service over following since
	# if it is present, the assumption is that it is being used, though multi id
	# is probably better.
	elsif ($key eq 'service'){
		$cmd = "$service_tool{$key}->[0] $service status";
	}
	# upstart, legacy, and finit, needs more data
	elsif ($key eq 'initctl' || $key eq 'dinitctl'){
		$cmd = "$service_tool{$key}->[0] status $service";
	}
	# runit
	elsif ($key eq 'sv'){
		$cmd = "$service_tool{$key}->[0] status $service";
	}
	# s6: note, shows s6-rc but uses s6-svstat; -n makes human-readable. Needs 
	# real data samples before adding.
	# elsif ($key eq 's6-rc'){
	#	$cmd = "$service_tool{$key}->[0] $service";
	# }
	# check or status or onestatus (netbsd)
	elsif ($key eq 'rc.d'){
		if (-e "$service_tool{$key}->[0]$service"){
			$status =  ($bsd_type && $bsd_type =~ /(dragonfly)/) ? 'status' : 'check';
			$cmd = "$service_tool{$key}->[0]$service check";
		}
		else {
			$result = 'not found';
		}
	}
	elsif ($key eq 'init.d'){
		if (-e "$service_tool{$key}->[0]$service"){
			$cmd = "$service_tool{$key}->[0]$service status";
		}
		else {
			$result = 'not found';
		}
	}
	@data = main::grabber("$cmd 2>&1",'','strip') if $cmd;
	# @data = ('bluetooth is running.');
	print "key: $key\n", Data::Dumper::Dumper \@data if $dbg[29];
	main::log_data('dump','service @data',\@data) if $b_log;
	for my $row (@data){
		my @working = split(/\s*:\s*/,$row);
		($value) = ('');
		# print "$working[0]::$working[1]\n";
		# Loaded: masked (Reason: Unit sddm.service is masked.)
		if ($working[0] eq 'Loaded'){
			# note: sshd shows ssh for ssh.service
			$working[1] =~ /^(.+?)\s*\(.*?\.service;\s+(\S+?);.*/;
			$result = lc($1) if $1;
			$result = lc($2) if $2; # this will be enabled/disabled
		}
		# Active: inactive (dead)
		elsif ($working[0] eq 'Active'){
			$working[1] =~ /^(.+?)\s*\((\S+?)\).*/;
			$value = lc($1) if $1 && (!$result || $result ne 'disabled');
			$value = $translate{$value} if $value && $translate{$value};
			$result .= ",$value" if ($result && $value);
			last;
		}
		# Status : running
		elsif ($working[0] eq 'Status' || $working[0] eq 'State'){
			$result = lc($working[1]);
			$result = $translate{$result} if $translate{$result};
			last;
		}
		# valid syntax, but service does not exist
		# * rc-service: service 'ntp' does not exist :: 
		# dinitctl: service not loaded [whether exists or not]
		elsif ($row =~ /$service.*?(not (exist|(be )?found|loaded)|no such (directory|file)|unrecognized)/i){
			$result = 'not found';
			last;
		}
		# means command directive doesn't exist, we don't know if service exists or not
		# * ntpd: unknown function 'disable' :: 
		elsif ($row =~ /unknown (directive|function)|Usage/i){
			last;
		}
		# rc-service: * status: started :: * status: stopped, fail handled in not exist test
		elsif ($working[0] eq '* status' && $working[1]){
			$result = lc($working[1]);
			$result = $translate{$result} if $translate{$result};
			last;
		}
		## start exists status detections
		elsif ($working[0] =~ /\b$service is ([a-z\s]+?)(\s+as\s.*|\s+\.\.\..*)?\.?$/){
			$result = lc($1);
			$result = $translate{$result} if $translate{$result};
			last;
		}
		# runit sv: run/down/fail - fail means not found
		# run: udevd: (pid 631) 641s :: down: sshd: 9s, normally up
		elsif ($working[1] && $working[1] eq $service && $working[0] =~ /^([a-z]+)$/){
			$result = lc($1);
			$result = $translate{$result} if $translate{$result};
			$result = "enabled,$result" if $working[2] && $working[2] =~ /normally up/i;
		}
		# OpenBSD: sshd(ok)
		elsif ($working[0] =~ /\b$service\s*\(([^\)]+)\)/){
			$result = lc($1);
			$result = $translate{$result} if $translate{$result};
			last;
		}
	}
	print "service result: $result\n" if $dbg[29];
	main::log_data('data',"result: $result") if $b_log;
	eval $end if $b_log;
	return $result;
}

sub set {
	eval $start if $b_log;
	$loaded{'service-tool'} = 1;
	my ($path);
	if ($path = main::check_program('systemctl')){
		# systemctl status ssh :: Loaded: / Active: 
		%service_tool = ('systemctl' => [$path,'systemctl']);
	}
	elsif ($path = main::check_program('rc-service')){
		# rc-service ssh status ::  * status: stopped
		%service_tool = ('rc-service' => [$path,'rc-service']);
	}
	elsif ($path = main::check_program('rcctl')){
		# rc-service ssh status ::  * status: stopped
		%service_tool = ('rcctl' => [$path,'rcctl']);
	}
	elsif ($path = main::check_program('service')){
		# service sshd status
		%service_tool = ('service' => [$path,'service']);
	}
	elsif ($path = main::check_program('sv')){
		%service_tool = ('sv' => [$path,'sv']);
	}
	# needs data, never seen output, but report if present
	elsif ($path = main::check_program('s6-svstat')){
		%service_tool = ('s6-rc' => [$path,'s6-rc']);
	}
	elsif ($path = main::check_program('dinitctl')){
		%service_tool = ('dinitctl' => [$path,'dinitctl']);
	}
	# make it last in tools, need more data
	elsif ($path = main::check_program('initctl')){
		%service_tool = ('initctl' => [$path,'initctl']);
	}
	# freebsd does not have 'check', netbsd does not have status
	elsif (-d '/etc/rc.d/'){
		# /etc/rc.d/ssh check :: ssh(ok|failed)
		%service_tool = ('rc.d' => ['/etc/rc.d/','/etc/rc.d']); 
	}
	elsif (-d '/etc/init.d/'){
		# /etc/init.d/ssh status :: Loaded: loaded (...)/ Active: active (...)
		%service_tool = ('init.d' => ['/etc/init.d/','/etc/init.d']);
	}
	eval $end if $b_log;
}
}
# $dbg[29] = 1; set_path(); print ServiceData::get('status','bluetooth'),"\n";

## ShellData
{