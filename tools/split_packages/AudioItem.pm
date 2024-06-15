package AudioItem;

sub get {
	eval $start if $b_log;
	my $rows = [];
	my $num = 0;
	if (%risc && !$use{'soc-audio'} && !$use{'pci-tool'}){
		my $key = 'Message';
		@$rows = ({
		main::key($num++,0,1,$key) => main::message('risc-pci',$risc{'id'})
		});
	}
	else {
		device_output($rows);
	}
	if (((%risc && !$use{'soc-audio'} && !$use{'pci-tool'}) || !@$rows) && 
	(my $file = $system_files{'asound-cards'})){
		asound_output($rows,$file);
	}
	usb_output($rows);
	# note: for servers often no audio, so we don't care about pci specific
	if (!@$rows){
		my $key = 'Message';
		my $type = 'device-data';
		if ($pci_tool && $alerts{$pci_tool}->{'action'} eq 'permissions'){
			$type = 'pci-card-data-root';
		}
		@$rows = ({main::key($num++,0,1,$key) => main::message($type,'')});
	}
	sound_output($rows);
	eval $end if $b_log;
	return $rows;
}

sub device_output {
	eval $start if $b_log;
	return if !$devices{'audio'};
	my $rows = $_[0];
	my ($j,$num) = (0,1);
	foreach my $row (@{$devices{'audio'}}){
		$num = 1;
		$j = scalar @$rows;
		my $driver = $row->[9];
		$driver ||= 'N/A';
		my $device = $row->[4];
		$device = ($device) ? main::clean_pci($device,'output') : 'N/A';
		# have seen absurdly verbose card descriptions, with non related data etc
		if (length($device) > 85 || $size{'max-cols'} < 110){
			$device = main::filter_pci_long($device);
		}
		push(@$rows, {
		main::key($num++,1,1,'Device') => $device,
		});
		if ($extra > 0 && $use{'pci-tool'} && $row->[12]){
			my $item = main::get_pci_vendor($row->[4],$row->[12]);
			$rows->[$j]{main::key($num++,0,2,'vendor')} = $item if $item;
		}
		$rows->[$j]{main::key($num++,1,2,'driver')} = $driver;
		if ($extra > 0 && !$bsd_type){
			if ($row->[9]){
				my $version = main::get_module_version($row->[9]);
				$rows->[$j]{main::key($num++,0,3,'v')} = $version if $version;
			}
		}
		if ($b_admin && $row->[10]){
			$row->[10] = main::get_driver_modules($row->[9],$row->[10]);
			$rows->[$j]{main::key($num++,0,3,'alternate')} = $row->[10] if $row->[10];
		}
		if ($extra > 0){
			my $bus_id = (!$row->[2] && !$row->[3]) ? 'N/A' : "$row->[2].$row->[3]";
			if ($extra > 1 && $bus_id ne 'N/A'){
				main::get_pcie_data($bus_id,$j,$rows,\$num);
			}
			$rows->[$j]{main::key($num++,0,2,'bus-ID')} = $bus_id;
		}
		if ($extra > 1){
			my $chip_id = main::get_chip_id($row->[5],$row->[6]);
			$rows->[$j]{main::key($num++,0,2,'chip-ID')} = $chip_id;
			if ($extra > 2 && $row->[1]){
				$rows->[$j]{main::key($num++,0,2,'class-ID')} = $row->[1];
			}
		}
		# print "$row->[0]\n";
	}
	eval $end if $b_log;
}

# this handles fringe cases where there is no card on pcibus,
# but there is a card present. I don't know the exact architecture
# involved but I know this situation exists on at least one old machine.
sub asound_output {
	eval $start if $b_log;
	my ($file,$rows) = @_;
	my ($device,$driver,$j,$num) = ('','',0,1);
	my @asound = main::reader($file);
	foreach (@asound){
		# filtering out modems and usb devices like webcams, this might get a
		# usb audio card as well, this will take some trial and error
		if (!/modem|usb/i && /^\s*[0-9]/){
			$num = 1;
			my @working = split(/:\s*/, $_);
			# now let's get 1 2
			$working[1] =~ /(.*)\s+-\s+(.*)/;
			$device = $2;
			$driver = $1;
			if ($device){
				$j = scalar @$rows;
				$driver ||= 'N/A';
				push(@$rows, {
				main::key($num++,1,1,'Device') => $device,
				main::key($num++,1,2,'driver') => $driver,
				});
				if ($extra > 0){
					my $version = main::get_module_version($driver);
					$rows->[$j]{main::key($num++,0,3,'v')} = $version if $version;
					$rows->[$j]{main::key($num++,0,2,'message')} = main::message('pci-advanced-data','');
				}
			}
		}
	}
	# print Data::Dumper:Dumper $rows;
	eval $end if $b_log;
}

sub usb_output {
	eval $start if $b_log;
	my $rows = $_[0];
	my (@ids,$path_id,$product,@temp2);
	my ($j,$num) = (0,1);
	return if !$usb{'audio'};
	foreach my $row (@{$usb{'audio'}}){
		$num = 1;
		$j = scalar @$rows;
		# make sure to reset, or second device trips last flag
		($path_id,$product) = ('','');
		$product = main::clean($row->[13]) if $row->[13];
		$product ||= 'N/A';
		$row->[15] ||= 'N/A';
		push(@$rows, {
		main::key($num++,1,1,'Device') => $product,
		main::key($num++,0,2,'driver') => $row->[15],
		main::key($num++,1,2,'type') => 'USB',
		});
		if ($extra > 0){
			# print "$j \n";
			if ($extra > 1){
				$row->[8] ||= 'N/A';
				$rows->[$j]{main::key($num++,0,3,'rev')} = $row->[8];
				if ($row->[17]){
					$rows->[$j]{main::key($num++,0,3,'speed')} = $row->[17];
				}
				if ($row->[24]){
					$rows->[$j]{main::key($num++,0,3,'lanes')} = $row->[24];
				}
				if ($b_admin && $row->[22]){
					$rows->[$j]{main::key($num++,0,3,'mode')} = $row->[22];
				}
			}
			$path_id = $row->[2] if $row->[2];
			$rows->[$j]{main::key($num++,0,2,'bus-ID')} = "$path_id:$row->[1]";
			if ($extra > 1){
				$row->[7] ||= 'N/A';
				$rows->[$j]{main::key($num++,0,2,'chip-ID')} = $row->[7];
			}
			if ($extra > 2){
				if (defined $row->[5] && $row->[5] ne ''){
					$rows->[$j]{main::key($num++,0,2,'class-ID')} = "$row->[4]$row->[5]";
				}
				if ($row->[16]){
					$rows->[$j]{main::key($num++,0,2,'serial')} = main::filter($row->[16]);
				}
			}
		}
	}
	eval $end if $b_log;
}

sub sound_output {
	eval $start if $b_log;
	my $rows = $_[0];
	my ($key,$program,$value);
	my ($j,$num) = (0,0);
	foreach my $server (@{sound_data()}){
		next if $extra < 1 && (!$server->[3] || $server->[3] !~ /^(active|.*api)/);
		$j = scalar @$rows;
		$server->[2] ||= 'N/A';
		$server->[3] ||= 'N/A';
		push(@$rows, {
		main::key($num++,1,1,$server->[0]) => $server->[1],
		main::key($num++,0,2,'v') => $server->[2],
		main::key($num++,0,2,'status') => $server->[3],
		});
		if ($extra > 1 && defined $server->[4] && ref $server->[4] eq 'ARRAY'){
			my $b_multi = (scalar @{$server->[4]} > 1) ? 1: 0;
			my $b_start;
			my $k = 0;
			foreach my $item (@{$server->[4]}){
				if ($item->[2] eq 'daemon'){
					$key = 'status';
					$value = $item->[3];
				}
				else {
					$key = 'type';
					$value = $item->[2];
				}
				if (!$b_multi){
					$rows->[$j]{main::key($num++,1,2,$item->[0])} = $item->[1];
					$rows->[$j]{main::key($num++,0,3,$key)} = $value;
				}
				else {
					$rows->[$j]{main::key($num++,1,2,$item->[0])} = '' if !$b_start;
					$b_start = 1;
					$k++;
					$rows->[$j]{main::key($num++,1,3,$k)} = $item->[1];
					$rows->[$j]{main::key($num++,0,4,$key)} = $value;
				}
			}
		}
		if ($b_admin){
			# Let long lines wrap for high tool counts, but best avoid too many tools
			my $join = (defined $server->[5] && length(join(',',@{$server->[5]})) > 40) ? ', ': ',';
			my $val = (defined $server->[5]) ? join($join,@{$server->[5]}) : 'N/A';
			$rows->[$j]{main::key($num++,0,2,'tools')} = $val;
		}
	}
	eval $end if $b_log;
}

# see docs/inxi-audio.txt for unused or alternate helpers/tools
sub sound_data {
	eval $start if $b_log;
	my ($config,$helpers,$name,$program,$status,$test,$tools,$type,$version);
	my $data = [];
	## API Types ##
	# not yet, user lib:  || main::globber('/usr/lib*{,/*}/libasound.so*')
	# the config test is expensive but will only trigger on servers with no audio
	# devices. Checks if kernel was compiled with SND_ items, even if no devices.
	if (!$bsd_type && -r "/boot/config-$uname[2]"){
		$config = "/boot/config-$uname[2]";
	}
	if ($system_files{'asound-version'} || 
	($config && (grep {/^CONFIG_SND_/} @{main::reader($config,'','ref')}))){
		$name = 'ALSA';
		$type = 'API';
		# always true until find better test for inactive API test
		if ($system_files{'asound-version'}){
			# avoid possible second line if compiled by user
			my $content = main::reader($system_files{'asound-version'},'',0);
			# we want the string after driver version for old and new ALSA
			# some alsa strings have the build date in (...) after Version
			if ($content =~ /Driver Version (\S+)(\s|\.?$)/){
				$version = $1;
				$version =~ s/\.$//; # trim off period
			}
			$status = 'kernel-api';
		}
		else {
			$status = 'inactive';
			$version = $uname[2];
			$version =~ s/^k//; # avoid double kk possible result
			$version = 'k' . $version;
		}
		if ($extra > 1){
			$test = [['osspd','daemon'],['aoss','oss-emulator'],
			['apulse','pulse-emulator'],];
			$helpers = sound_helpers($test);
		}
		if ($b_admin){
			$test = [qw(alsactl alsamixer alsamixergui amixer)];
			$tools = sound_tools($test);
		}
		push(@$data,[$type,$name,$version,$status,$helpers,$tools]);
		($status,$version,$helpers,$tools) = ('','',undef,undef);
	}
	# sndstat file may be removed in linux oss, but ossinfo part of oss4-base
	# alsa oss compat driver will create /dev/sndstat in linux however
	# Note: kernel compile: SOUND_OSS 
	if ((-e '/dev/sndstat' && !$system_files{'asound-version'}) || 
	main::check_program('ossinfo')){
		$name = 'OSS';
		# not a great test, but ok for now, check on current Linux, seems unlikely 
		# to find OSS on OpenBSD in general.
		if ($bsd_type){
			$status = (-e '/dev/sndstat') ? 'kernel-api' : 'inactive';
		}
		else {
			$status = (-e '/dev/sndstat') ? 'active' : 'off?';
		}
		$type = 'API'; # not strictly an API on linux, but almost nobody uses it.
		# not certain to be cross distro, Debian/Ubuntu at least.
		if (-e '/etc/oss4/version.dat'){
			$version = main::reader('/etc/oss4/version.dat','',0);
		}
		elsif ($sysctl{'audio'}){
			$version = (grep {/^hw.snd.version:/} @{$sysctl{'audio'}})[0];
			$version = (split(/:\s*/,$version),1)[1] if $version;
			$version =~ s|/.*$|| if $version;
		}
		if ($extra > 1){
			# virtual_oss freebsd, not verified; osspd-alsa/pulseaudio no path exec
			$test = [['virtual_oss','daemon'],['virtual_equalizer','plugin']];
			$helpers = sound_helpers($test);
		}
		if ($b_admin){
			# *mixer are FreeBSD tools
			$test = [qw(dsbmixer mixer ossctl ossinfo ossmix ossxmix vmixctl)];
			$tools = sound_tools($test);
		}
		push(@$data,[$type,$name,$version,$status,$helpers,$tools]);
		($status,$version,$helpers,$tools) = ('','',undef,undef);
	}
	if ($program = main::check_program('sndiod')){
		if ($bsd_type){
			push(@$data, ['API','sndio',undef,'sound-api',undef,undef]);
		}
		$name = 'sndiod';
		# verified: accurate
		$status = (grep {/sndiod/} @ps_cmd) ? 'active': 'off';
		$type = 'Server';
		# $version: no known method
		if ($b_admin){
			$test = [qw(aucat midicat mixerctl sndioctl)];
			$tools = sound_tools($test);
		}
		push(@$data,[$type,$name,$version,$status,$helpers,$tools]);
		($status,$version,$helpers,$tools) = ('','',undef,undef);
	}
	## Servers ##
	if ($program = main::check_program('artsd')){
		($name,$version) = ProgramData::full('arts',$program);
		$status = (grep {/artsd/} @ps_cmd) ? 'active': 'off';
		$type = 'Server';
		if ($extra > 1){
			$test = [['artswrapper','daemon'],];
			$helpers = sound_helpers($test);
		}
		if ($b_admin){
			$test = [qw(artsbuilder artsdsp)];
			$tools = sound_tools($test);
		}
		push(@$data,[$type,$name,$version,$status,$helpers,$tools]);
		($status,$version,$helpers,$tools) = ('','',undef,undef);
	}
	# pulseaudio-esound-compat has esd pointing to esdcompat
	if (($program = main::check_program('esd')) && 
	!main::check_program('esdcompat')){
		($name,$version) = ProgramData::full('esound',$program);
		$status = (grep {/\besd\b/} @ps_cmd) ? 'active': 'off';
		$type = 'Server';
		# if ($extra > 1){
		#	$test = [['','daemon'],];
		#	$helpers = sound_helpers($test);
		# }
		if ($b_admin){
			$test = [qw(esdcat esdctl esddsp)];
			$tools = sound_tools($test);
		}
		push(@$data,[$type,$name,$version,$status,$helpers,$tools]);
		($status,$version,$helpers,$tools) = ('','',undef,undef);
	}
	if ($program = main::check_program('jackd')){
		($name,$version) = ProgramData::full('jack',$program);
		$status = jack_status();
		$type = 'Server';
		if ($extra > 1){
			$test = [['a2jmidid','daemon'],['nsmd','daemon']];
			$helpers = sound_helpers($test);
		}
		if ($b_admin){
			$test = [qw(agordejo cadence jack_control jack_mixer qjackctl)];
			$tools = sound_tools($test);
		}
		push(@$data,[$type,$name,$version,$status,$helpers,$tools]);
		($status,$version,$helpers,$tools) = ('','',undef,undef);
	}
	if ($program = main::check_program('nasd')){
		($name,$version) = ProgramData::full('nas',$program);
		$status = (grep {/(^|\/)nasd/} @ps_cmd) ? 'active': 'off';
		$type = 'Server';
		if ($extra > 1){
			$test = [['audiooss','oss-compat'],];
			$helpers = sound_helpers($test);
		}
		if ($b_admin){
			$test = [qw(auctl auinfo)];
			$tools = sound_tools($test);
		}
		push(@$data,[$type,$name,$version,$status,$helpers,$tools]);
		($status,$version,$helpers,$tools) = ('','',undef,undef);
	}
	if ($program = main::check_program('pipewire')){
		($name,$version) = ProgramData::full('pipewire',$program);
		$status = pipewire_status();
		$type = 'Server';
		if ($extra > 1){
			# pipewire-alsa is a plugin, but is just some config files
			$test = [['pipewire-pulse','daemon'],['pipewire-media-session','daemon'],
			['wireplumber','daemon'],
			['pipewire-alsa','plugin','/etc/alsa/conf.d/*-pipewire-default.conf'],
			['pw-jack','plugin']];
			$helpers = sound_helpers($test);
		}
		if ($b_admin){
			$test = [qw(pw-cat pw-cli wpctl)];
			# note: pactl can be used w/pipewire-pulse;
			if (!main::check_program('pulseaudio') && 
			main::check_program('pipewire-pulse')){
				splice(@$test,0,0,'pactl');
			}
			$tools = sound_tools($test);
		}
		push(@$data,[$type,$name,$version,$status,$helpers,$tools]);
		($status,$version,$helpers,$tools) = ('','',undef,undef);
	}
	# note: pactl info/list/stat could be used
	if ($program = main::check_program('pulseaudio')){
		($name,$version) = ProgramData::full('pulseaudio',$program);
		$status = pulse_status($program);
		$type = 'Server';
		if ($extra > 1){
			$test = [['pulseaudio-dlna','daemon'],
			['pulseaudio-alsa','plugin','/etc/alsa/conf.d/*-pulseaudio-default.conf'],
			['esdcompat','plugin'],
			['pulseaudio-jack','module','/usr/lib/pulse*/modules/module-jack-sink.so']];
			$helpers = sound_helpers($test);
		}
		if ($b_admin){
			$test = [qw(pacat pactl paman pamix pamixer pavucontrol pulsemixer)];
			$tools = sound_tools($test);
		}
		push(@$data,[$type,$name,$version,$status,$helpers,$tools]);
		($status,$version,$helpers,$tools) = ('','',undef,undef);
	}
	if ($program = main::check_program('roard')){
		($name,$version) = ProgramData::full('roaraudio',$program);# no version so far
		$status = (grep {/roard/} @ps_cmd) ? 'active': 'off';
		$type = 'Server';
		if ($extra > 1){
			$test = [['roarplaylistd','daemon'],['roarify','pulse/viff-emulation']];
			$helpers = sound_helpers($test);
		}
		if ($b_admin){
			$test = [qw(roarcat roarctl)];
			$tools = sound_tools($test);
		}
		push(@$data,[$type,$name,$version,$status,$helpers,$tools]);
		($status,$version,$helpers,$tools) = ('','',undef,undef);
	}
	main::log_data('dump','sound data: @$data',$data) if $b_log;
	print 'Sound data: ',  Data::Dumper::Dumper $data if $dbg[26];
	eval $end if $b_log;
	return $data;
}

# assume if jackd running we have active jack, update if required
sub jack_status {
	eval $start if $b_log;
	my $status;
	if (grep {/jackd/} @ps_cmd){
		if (my $program = main::check_program('jack_control')){
			system("$program status > /dev/null 2>&1");
			# 0 means running, always, else 1.
			if ($? == 0){
				$status = 'active';
			}
			else {
				$status = ($b_root) ? main::message('audio-server-root-na') : 'off';
			}
		}
		$status = main::message('audio-server-process-on') if !$status;
	}
	else {
		$status = 'off';
	}
	eval $end if $b_log;
	return $status;
}

# pipewire is complicated, it can be there and running without being active server
# This is NOT verified as valid true/yes case!!
sub pipewire_status {
	eval $start if $b_log;
	my ($b_process,$program,$status,@data);
	if (grep {/(^|\/)pipewire(d|\s|:|$)/} @ps_cmd){
		# note: if pipewire was stopped but not masked, pw-cli can start service so
		# only use if pipewire process already running
		if ($program = main::check_program('pw-cli')){
			@data = qx($program ls 2>/dev/null);
			main::log_data('dump','pw-cli @data', \@data) if $b_log;
			print 'pw-cli: ', Data::Dumper::Dumper \@data if $dbg[52];
			if (@data){
				$status = (grep {/media\.class\s*=\s*"(Audio|Midi)/i} @data) ? 'active' : 'off';
			}
			elsif ($b_root){
				$status = main::message('audio-server-root-na');
			}
		}
		$status = main::message('audio-server-process-on') if !$status;
	}
	else {
		$status = 'off';
	}
	eval $end if $b_log;
	return $status;
}

# pulse might be running through pipewire
sub pulse_status {
	eval $start if $b_log;
	my $program = $_[0];
	my ($status,@data);
	if (grep {/(^|\/)pulseaudiod?\b/} @ps_cmd){
		# this is almost certainly not needed, but keep for now
		system("$program --check > /dev/null 2>&1");
		# 0 means running, always, other could be an error.
		if ($? == 0){
			$status = 'active';
		}
		else {
			$status = ($b_root) ? main::message('audio-server-root-on') : 'off';
		}
	}
	else {
		# can't use pactl info test because starts pulseaudio/pipewire if unmasked
		if (main::check_program('pipewire-pulse') && 
		(grep {/(^|\/)pipewire-pulse/} @ps_cmd)){
			$status = main::message('audio-server-on-pipewire-pulse');
		}
		else {
			$status = 'off';
		}
	}
	eval $end if $b_log;
	return $status;
}

sub sound_helpers {
	eval $start if $b_log;
	my $test = $_[0];
	my ($helpers,$name,$status,$key);
	foreach my $item (@$test){
		if (main::check_program($item->[0]) || 
		(defined $item->[2] && main::globber($item->[2]))){
			$name = $item->[0];
			$key = 'with';
			# these are active/off daemons unless not a daemon
			if ($item->[1] eq 'daemon'){
				$status = (grep {/$item->[0]/} @ps_cmd) ? 'active':'off' ;
			}
			else {
				$status = $item->[1];
			}
			push(@$helpers,[$key,$name,$item->[1],$status]);
		}
	}
	# push(@$helpers, ['with','pipewire-pulse','daemon','active'],['with','pw-jack','plugin']);
	# push(@$helpers, ['with','pipewire-pulse','daemon','active']);
	eval $end if $b_log;
	# print Data::Dumper::Dumper $helpers;
	return $helpers;
}

sub sound_tools {
	eval $start if $b_log;
	my $test = $_[0];
	my $tools;
	foreach my $item (@$test){
		if (main::check_program($item)){
			push(@$tools,$item);
		}
	}
	eval $end if $b_log;
	# print Data::Dumper::Dumper $tools;
	return $tools;
}
}

## BatteryItem
{