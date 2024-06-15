package GraphicItem;
my ($b_primary,$b_wayland_data,%graphics,%mesa_drivers,
$monitor_ids,$monitor_map);
my ($gpu_amd,$gpu_intel,$gpu_nv);

sub get {
	eval $start if $b_log;
	my $rows = [];
	my $num = 0;
	if (%risc && !$use{'soc-gfx'} && !$use{'pci-tool'}){
		my $key = 'Message';
		@$rows = ({
		main::key($num++,0,1,$key) => main::message('risc-pci',$risc{'id'})
		});
	}
	else {
		device_output($rows);
		($gpu_amd,$gpu_intel,$gpu_nv) = ();
		if (!@$rows){
			my $key = 'Message';
			my $message = '';
			my $type = 'pci-card-data';
			if ($pci_tool && $alerts{$pci_tool}->{'action'} eq 'permissions'){
				$type = 'pci-card-data-root';
			}
			elsif (!$bsd_type && !%risc && !$pci_tool && 
			$alerts{'lspci'}->{'action'} && 
			$alerts{'lspci'}->{'action'} eq 'missing'){
				$message = $alerts{'lspci'}->{'message'};
			}
			$message = main::message($type,'') if !$message;
			@$rows = ({
			main::key($num++,0,1,$key) => $message
			});
		}
	}
	# note: not perfect, but we need usb gfx to show for all types, soc, pci, etc
	usb_output($rows);
	display_output($rows);
	display_api($rows);
	(%graphics,$monitor_ids,$monitor_map) = ();
	eval $end if $b_log;
	return $rows;
}

## DEVICE OUTPUT ##
sub device_output {
	eval $start if $b_log;
	return if !$devices{'graphics'};
	my $rows = $_[0];
	my ($j,$num) = (0,1);
	my ($bus_id);
	set_monitors_sys() if !$monitor_ids && -e '/sys/class/drm';
	foreach my $row (@{$devices{'graphics'}}){
		$num = 1;
		# print "$row->[0] $row->[3]\n";
		# not using 3D controller yet, needs research: |3D controller |display controller
		# note: this is strange, but all of these can be either a separate or the same
		# card. However, by comparing bus id, say: 00:02.0 we can determine that the
		# cards are  either the same or different. We want only the .0 version as a valid
		# card. .1 would be for example: Display Adapter with bus id x:xx.1, not the right one
		next if $row->[3] != 0;
		# print "$row->[0] $row->[3]\n";
		$j = scalar @$rows;
		my $device = main::trimmer($row->[4]);
		($bus_id) = ();
		$device = ($device) ? main::clean_pci($device,'output') : 'N/A';
		# have seen absurdly verbose card descriptions, with non related data etc
		if (length($device) > 85 || $size{'max-cols'} < 110){
			$device = main::filter_pci_long($device);
		}
		push(@$rows, {
		main::key($num++,1,1,'Device') => $device,
		},);
		if ($extra > 0 && $use{'pci-tool'} && $row->[12]){
			my $item = main::get_pci_vendor($row->[4],$row->[12]);
			$rows->[$j]{main::key($num++,0,2,'vendor')} = $item if $item;
		}
		push(@{$graphics{'gpu-drivers'}},$row->[9]) if $row->[9];
		my $driver = ($row->[9]) ? $row->[9]:'N/A';
		$rows->[$j]{main::key($num++,1,2,'driver')} = $driver;
		if ($row->[9] && !$bsd_type){
			my $version = main::get_module_version($row->[9]);
			$version ||= 'N/A';
			$rows->[$j]{main::key($num++,0,3,'v')} = $version;
		}
		if ($b_admin && $row->[10]){
			$row->[10] = main::get_driver_modules($row->[9],$row->[10]);
			$rows->[$j]{main::key($num++,0,3,'alternate')} = $row->[10] if $row->[10];
		}
		if ($extra > 0 && $row->[5] && $row->[6] && 
		$row->[5] =~ /^(1002|10de|12d2|8086)$/){
			# legacy: 1180 0df7 0029 current: 13bc 1c8d 24b1 regex: H100, RTX 4000
			# ($row->[5],$row->[6],$row->[4]) = ('12de','0029','');
			my ($gpu_data,$b_nv) = gpu_data($row->[5],$row->[6],$row->[4]);
			if (!$bsd_type && $b_nv && $b_admin){
				if ($gpu_data->{'legacy'}){
					$rows->[$j]{main::key($num++,1,3,'non-free')} = '';
					$rows->[$j]{main::key($num++,0,4,'series')} = $gpu_data->{'series'};
					$rows->[$j]{main::key($num++,0,4,'status')} = $gpu_data->{'status'};
					if ($gpu_data->{'xorg'}){
						$rows->[$j]{main::key($num++,1,4,'last')} = '';
						$rows->[$j]{main::key($num++,0,5,'release')} = $gpu_data->{'release'};
						$rows->[$j]{main::key($num++,0,5,'kernel')} = $gpu_data->{'kernel'};
						$rows->[$j]{main::key($num++,0,5,'xorg')} = $gpu_data->{'xorg'};
					}
				}
				else {
					$gpu_data->{'series'} ||= 'N/A';
					$rows->[$j]{main::key($num++,1,3,'non-free')} = $gpu_data->{'series'};
					$rows->[$j]{main::key($num++,0,4,'status')} = $gpu_data->{'status'};
				}
			}
			if ($gpu_data->{'arch'}){
				$rows->[$j]{main::key($num++,1,2,'arch')} = $gpu_data->{'arch'};
				# we don't need to see repeated values here, but usually code is different.
				if ($b_admin && $gpu_data->{'code'} && 
				$gpu_data->{'code'} ne $gpu_data->{'arch'}){
					$rows->[$j]{main::key($num++,0,3,'code')} = $gpu_data->{'code'};
				}
				if ($b_admin && $gpu_data->{'process'}){
					$rows->[$j]{main::key($num++,0,3,'process')} = $gpu_data->{'process'};
				}
				if ($b_admin && $gpu_data->{'years'}){
					$rows->[$j]{main::key($num++,0,3,'built')} = $gpu_data->{'years'};
				}
			}
		}
		if ($extra > 0){
			$bus_id = (!$row->[2] && !$row->[3]) ? 'N/A' : "$row->[2].$row->[3]";
			if ($extra > 1 && $bus_id ne 'N/A'){
				main::get_pcie_data($bus_id,$j,$rows,\$num,'gpu');
			}
			if ($extra > 1 && $monitor_ids){
				port_output($bus_id,$j,$rows,\$num);
			}
			$rows->[$j]{main::key($num++,0,2,'bus-ID')} = $bus_id;
		}
		if ($extra > 1){
			my $chip_id = main::get_chip_id($row->[5],$row->[6]);
			$rows->[$j]{main::key($num++,0,2,'chip-ID')} = $chip_id;
		}
		if ($extra > 2 && $row->[1]){
			$rows->[$j]{main::key($num++,0,2,'class-ID')} = $row->[1];
		}
		if (!$bsd_type && $extra > 0 && $bus_id ne 'N/A' && $bus_id =~ /\.0$/){
			my $temp = main::get_device_temp($bus_id);
			if ($temp){
				$rows->[$j]{main::key($num++,0,2,'temp')} = $temp . ' C';
			}
		}
		# print "$row->[0]\n";
	}
	eval $end if $b_log;
}

sub usb_output {
	eval $start if $b_log;
	my $rows = $_[0];
	my (@ids,$driver,$path_id,$product,@temp2);
	my ($j,$num) = (0,1);
	return if !$usb{'graphics'};
	foreach my $row (@{$usb{'graphics'}}){
		# these tests only work for /sys based usb data for now
		$num = 1;
		$j = scalar @$rows;
		# make sure to reset, or second device trips last flag
		($driver,$path_id,$product) = ('','','');
		$product = main::clean($row->[13]) if $row->[13];
		$driver = $row->[15] if $row->[15];
		$path_id = $row->[2] if $row->[2];
		$product ||= 'N/A';
		# note: for real usb video out, no generic drivers? webcams may have one though
		if (!$driver){
			if ($row->[14] eq 'audio-video'){
				$driver = 'N/A';
			}
			else {
				$driver = 'N/A';
			}
		}
		push(@$rows, {
		main::key($num++,1,1,'Device') => $product,
		main::key($num++,0,2,'driver') => $driver,
		main::key($num++,1,2,'type') => 'USB',
		},);
		if ($extra > 0){
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
			my $bus_id = "$path_id:$row->[1]";
			if ($monitor_ids){
				port_output($bus_id,$j,$rows,\$num);
			}
			$rows->[$j]{main::key($num++,0,2,'bus-ID')} = $bus_id;
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

# args: $rows, $num by ref
sub port_output {
	my ($bus_id,$j,$rows,$num) = @_;
	my (@connected,@disabled,@empty);
	foreach my $id (keys %$monitor_ids){
		next if !$monitor_ids->{$id}{'status'};
		if ($monitor_ids->{$id}{'path'} =~ m|\Q$bus_id/drm/\E|){
			# status can be: connected|disconnected|unknown
			if ($monitor_ids->{$id}{'status'} eq 'connected'){
				if ($monitor_ids->{$id}{'enabled'} eq 'enabled'){
					push(@connected,$id);
				}
				else {
					push(@disabled,$id);
				}
			}
			else {
				push(@empty,$id);
			}
		}
	}
	if (@connected || @empty || @disabled){
		my ($off,$active,$unused);
		my $split = ','; # add space if many to allow for wrapping
		$rows->[$j]{main::key($$num++,1,2,'ports')} = '';
		$split = ', ' if scalar @connected > 3;
		$active = (@connected) ? join($split,sort @connected) : 'none';
		$rows->[$j]{main::key($$num++,0,3,'active')} = $active;
		if (@disabled){
			$split = (scalar @disabled > 3) ? ', ' : ',';
			$off = join($split,sort @disabled);
			$rows->[$j]{main::key($$num++,0,3,'off')} = $off;
		}
		$split = (scalar @empty > 3) ? ', ' : ',';
		$unused = (@empty) ? join($split,sort @empty) : 'none';
		$rows->[$j]{main::key($$num++,0,3,'empty')} = $unused;
	}
}

## DISPLAY OUTPUT ##
sub display_output(){
	eval $start if $b_log;
	my $rows = $_[0];
	my ($num,$j) = (0,scalar @$rows);
	# note: these may not always be set, they won't be out of X, for example
	display_protocol();
	# get rid of all inactive or disabled monitor port ids
	set_active_monitors() if $monitor_ids;
	$graphics{'protocol'} = 'wayland' if $force{'wayland'};
	# note, since the compositor is the server with wayland, always show it
	if ($extra > 1 || $graphics{'protocol'} eq 'wayland'){
		set_compositor_data();
	}
	if ($b_display){
		# Add compositors as data sources found
		if ($graphics{'protocol'} eq 'wayland'){
			display_data_wayland();
		}
		if (!$b_wayland_data){
			display_data_x() if !$force{'wayland'};
		}
	}
	else {
		$graphics{'tty'} = tty_data();
	}
	# no xdpyinfo installed
	# undef $graphics{'x-server'};
	# Completes X server data if no previous detections, tests/adds xwayland
	display_server_data(); 
	if (!defined $graphics{'display-id'} && defined $ENV{'DISPLAY'}){
		$graphics{'display-id'} = $ENV{'DISPLAY'};
	}
	# print Data::Dumper::Dumper $graphics{'x-server'};
	# print Data::Dumper::Dumper \%graphics;
	if (%graphics){
		my ($driver_note,$resolution,$server_string) = ('','','');
		my ($b_screen_monitors);
		my $x_drivers = (!$force{'wayland'}) ? display_drivers_x() : [];
		# print 'result: ', Data::Dumper::Dumper $x_drivers;
		# print "$graphics{'x-server'} $graphics{'x-version'} $graphics{'x-vendor-release'}","\n";
		if ($graphics{'x-server'}){
			$server_string = $graphics{'x-server'}->[0][0];
			# print "$server_string\n";
		}
		if (!$graphics{'protocol'} && !$server_string && !$graphics{'x-server'} && 
		!@$x_drivers && !$graphics{'compositors'}){
			$server_string = main::message('display-server');
			push(@$rows,{
			main::key($num++,1,1,'Display') => '',
			main::key($num++,0,2,'server') => $server_string,
			});
		}
		else {
			$server_string ||= 'N/A';
			push(@$rows, {
			main::key($num++,1,1,'Display') => $graphics{'protocol'},
			main::key($num++,1,2,'server') => $server_string,
			});
			if ($graphics{'x-server'} && $graphics{'x-server'}->[0][1]){
				$rows->[$j]{main::key($num++,0,3,'v')} = $graphics{'x-server'}->[0][1];
			}
			if ($graphics{'x-server'} && $graphics{'x-server'}->[1][0]){
				$rows->[$j]{main::key($num++,1,3,'with')} = $graphics{'x-server'}->[1][0];
				if ($graphics{'x-server'}->[1][1]){
					$rows->[$j]{main::key($num++,0,4,'v')} = $graphics{'x-server'}->[1][1];
				}
			}
			if ($graphics{'compositors'}){
				if (scalar @{$graphics{'compositors'}} == 1){
					$rows->[$j]{main::key($num++,1,2,'compositor')} = $graphics{'compositors'}->[0][0];
					if ($graphics{'compositors'}->[0][1]){
						$rows->[$j]{main::key($num++,0,3,'v')} = $graphics{'compositors'}->[0][1];
					}
				}
				else {
					my $i =1;
					$rows->[$j]{main::key($num++,1,2,'compositors')} = '';
					foreach (@{$graphics{'compositors'}}){
						$rows->[$j]{main::key($num++,1,3,$i)} = $_->[0];
						if ($_->[1]){
							$rows->[$j]{main::key($num++,0,4,'v')} = $_->[1];
						}
						$i++;
					}
				}
			}
			# note: if no xorg log, and if wayland, there will be no xorg drivers, 
			# obviously, so we use the driver(s) found in the card section.
			# Those come from lspci kernel drivers so should be no xorg/wayland issues.
			if (!@$x_drivers || !$x_drivers->[0]){
				# Fallback: specific case: in Arch/Manjaro gdm run systems, Xorg.0.log is 
				# located inside this directory, which is not readable unless you are root
				# Normally Arch gdm log is here: ~/.local/share/xorg/Xorg.1.log
				if (!$graphics{'protocol'} || $graphics{'protocol'} ne 'wayland'){
					# Problem: as root, wayland has no info anyway, including wayland detection.
					if (-e '/var/lib/gdm' && !$b_root){
						if ($graphics{'gpu-drivers'}){
							$driver_note = main::message('display-driver-na-try-root');
						}
						else {
							$driver_note = main::message('root-suggested');
						}
					}
				}
			}
			# if TinyX, will always have display-driver set
			if ($graphics{'tinyx'} && $graphics{'display-driver'}){
				$rows->[$j]{main::key($num++,0,2,'driver')} = join(',',@{$graphics{'display-driver'}});
			}
			else {
				my $gpu_drivers = gpu_drivers_sys('all');
				my $note_indent = 4;
				if (@$gpu_drivers || $graphics{'dri-drivers'} || @$x_drivers){
					$rows->[$j]{main::key($num++,1,2,'driver')} = '';
					# The only wayland setups with x drivers have xorg, transitional that is.
					if (@$x_drivers){
						$rows->[$j]{main::key($num++,1,3,'X')} = '';
						my $driver = ($x_drivers->[0]) ? join(',',@{$x_drivers->[0]}) : 'N/A';
						$rows->[$j]{main::key($num++,1,4,'loaded')} = $driver;
						if ($x_drivers->[1]){
							$rows->[$j]{main::key($num++,0,4,'unloaded')} = join(',',@{$x_drivers->[1]});
						}
						if ($x_drivers->[2]){
							$rows->[$j]{main::key($num++,0,4,'failed')} = join(',',@{$x_drivers->[2]});
						}
						if ($extra > 1 && $x_drivers->[3]){
							$rows->[$j]{main::key($num++,0,4,'alternate')} = join(',',@{$x_drivers->[3]});
						}
					}
					if ($graphics{'dri-drivers'}){
						# note: if want to exclude if matches gpu/x driver, loop through and test.
						# Here using all dri drivers found.
						$rows->[$j]{main::key($num++,1,3,'dri')} = join(',',@{$graphics{'dri-drivers'}});
					}
					my $drivers;
					if (@$gpu_drivers){
						$drivers = join(',',@$gpu_drivers);
					}
					else {
						$drivers = ($graphics{'gpu-drivers'}) ? join(',',@{$graphics{'gpu-drivers'}}): 'N/A';
					}
					$rows->[$j]{main::key($num++,1,3,'gpu')} = $drivers;
				}
				else {
					$note_indent = 3;
					$rows->[$j]{main::key($num++,1,2,'driver')} = 'N/A';
				}
				if ($driver_note){
					$rows->[$j]{main::key($num++,0,$note_indent,'note')} = $driver_note;
				}
			}
		}
		if (!$show{'graphic-basic'} && $extra > 1 && $graphics{'display-rect'}){
			$rows->[$j]{main::key($num++,0,2,'d-rect')} = $graphics{'display-rect'};
		}
		if (!$show{'graphic-basic'} && $extra > 1){
			if (defined $graphics{'display-id'}){
				$rows->[$j]{main::key($num++,0,2,'display-ID')} = $graphics{'display-id'};
			}
			if (defined $graphics{'display-screens'}){
				$rows->[$j]{main::key($num++,0,2,'screens')} = $graphics{'display-screens'};
			}
			if (defined $graphics{'display-default-screen'} && 
			 $graphics{'display-screens'} && $graphics{'display-screens'} > 1){
				$rows->[$j]{main::key($num++,0,2,'default screen')} = $graphics{'display-default-screen'};
			}
		}
		# TinyX may pack actual resolution data into no-screens if it was found
		if ($graphics{'no-screens'}){
			my $res = (!$show{'graphic-basic'} && $extra > 1 && !$graphics{'tinyx'}) ? 'note' : 'resolution';
			$rows->[$j]{main::key($num++,0,2,$res)} = $graphics{'no-screens'};
		}
		elsif ($graphics{'screens'}){
			my ($diag,$dpi,$hz,$size);
			my ($m_count,$basic_count,$screen_count) = (0,0,0);
			my $s_count = ($graphics{'screens'}) ? scalar @{$graphics{'screens'}}:  0;
			foreach my $main (@{$graphics{'screens'}}){
				$m_count = scalar keys %{$main->{'monitors'}} if $main->{'monitors'};
				$screen_count++;
				($diag,$dpi,$hz,$resolution,$size) = ();
				$j++ if !$show{'graphic-basic'};
				if (!$show{'graphic-basic'} || $m_count == 0){
					if (!$show{'graphic-basic'} && defined $main->{'screen'}){
						$rows->[$j]{main::key($num++,1,2,'Screen')} = $main->{'screen'};
					}
					if ($main->{'res-x'} && $main->{'res-y'}){
						$resolution = $main->{'res-x'} . 'x' . $main->{'res-y'};
						if ($main->{'hz'} && $show{'graphic-basic'}){
							$resolution .= '~' . $main->{'hz'} . 'Hz';
						}
					}
					$resolution ||= 'N/A';
					if ($s_count == 1 || !$show{'graphic-basic'}){
						$rows->[$j]{main::key($num++,0,3,'s-res')} = $resolution;
					}
					elsif ($show{'graphic-basic'}){
						$rows->[$j]{main::key($num++,0,3,'s-res')} = '' if $screen_count == 1;
						$rows->[$j]{main::key($num++,0,3,$screen_count)} = $resolution;
					}
					if ($main->{'s-dpi'} && (!$show{'graphic-basic'} && $extra > 1)){
						$rows->[$j]{main::key($num++,0,3,'s-dpi')} = $main->{'s-dpi'};
					}
					if (!$show{'graphic-basic'} && $extra > 2){
						if ($main->{'size-missing'}){
							$rows->[$j]{main::key($num++,0,3,'s-size')} = $main->{'size-missing'};
						}
						else {
							if ($main->{'size-x'} && $main->{'size-y'}){
								$size = $main->{'size-x'} . 'x' . $main->{'size-y'} . 
								'mm ('. $main->{'size-x-i'} . 'x' . $main->{'size-y-i'} . '")';
								$rows->[$j]{main::key($num++,0,3,'s-size')} = $size;
							}
							if ($main->{'diagonal'}){
								$diag = $main->{'diagonal-m'} . 'mm ('. $main->{'diagonal'} . '")';
								$rows->[$j]{main::key($num++,0,3,'s-diag')} = $diag;
							}
						}
					}
				}
				if ($main->{'monitors'}){
					# print $basic_count . '::' . $m_count, "\n";
					$b_screen_monitors = 1;
					if ($show{'graphic-basic'}){
						monitors_output_basic('screen',$main->{'monitors'},
						$main->{'s-dpi'},$j,$rows,\$num);
					}
					else {
						monitors_output_full('screen',$main->{'monitors'},
						\$j,$rows,\$num);
					}
				}
				elsif (!$show{'graphic-basic'} && $graphics{'no-monitors'}){
					$rows->[$j]{main::key($num++,0,4,'monitors')} = $graphics{'no-monitors'};
				}
			}
		}
		elsif (!$b_display){
			$graphics{'tty'} ||= 'N/A';
			$rows->[$j]{main::key($num++,0,2,'tty')} = $graphics{'tty'};
		}
		# fallback, if no xrandr/xdpyinfo, if wayland, if console. Note we've 
		# deleted each key used in advanced_monitor_data() so those won't show again
		if (!$b_screen_monitors && $monitor_ids && %$monitor_ids){
			if ($show{'graphic-basic'}){
				monitors_output_basic('monitor',$monitor_ids,'',$j,$rows,\$num);
			}
			else {
				monitors_output_full('monitor',$monitor_ids,\$j,$rows,\$num);
			}
		}
	}
	eval $end if $b_log;
}

sub monitors_output_basic {
	eval $start if $b_log;
	my ($type,$monitors,$s_dpi,$j,$row,$num) = @_;
	my ($dpi,$resolution);
	my ($basic_count,$m_count) = (0,scalar keys %{$monitors});
	foreach my $key (sort keys %{$monitors}){
		if ($type eq 'monitor' && (!$monitors->{$key}{'res-x'} || 
		!$monitors->{$key}{'res-y'})){
			next;
		}
		($dpi,$resolution) = ();
		$basic_count++;
		if ($monitors->{$key}{'res-x'} && $monitors->{$key}{'res-y'}){
			$resolution = $monitors->{$key}{'res-x'} . 'x' . $monitors->{$key}{'res-y'};
		}
		# using main, not monitor, dpi because we want xorg dpi, not physical screen dpi
		$dpi = $s_dpi if $resolution && $extra > 1 && $s_dpi;
		if ($monitors->{$key}{'hz'} && $resolution){
			$resolution .= '~' . $monitors->{$key}{'hz'} . 'Hz';
		}
		$resolution ||= 'N/A';
		if ($basic_count == 1 && $m_count == 1){
			$row->[$j]{main::key($$num++,0,2,'resolution')} = $resolution;
		}
		else {
			if ($basic_count == 1){
				$row->[$j]{main::key($$num++,1,2,'resolution')} = '';
			}
			$row->[$j]{main::key($$num++,0,3,$basic_count)} = $resolution;
		}
		if (!$show{'graphic-basic'} && $m_count == $basic_count && $dpi){
			$row->[$j]{main::key($$num++,0,2,'s-dpi')} = $dpi;
		}
	}
	eval $end if $b_log;
}

# args: $j, $row, $num passed by ref
sub monitors_output_full {
	eval $start if $b_log;
	my ($type,$monitors,$j,$rows,$num) = @_;
	my ($b_no_size,$resolution);
	my ($m1,$m2,$m3,$m4) = ($type eq 'screen') ? (3,4,5,6) : (2,3,4,5);
	# note: in case where mapped id != sys id, the key will not match 'monitor'
	foreach my $key (sort keys %{$monitors}){
		$$j++;
		$rows->[$$j]{main::key($$num++,1,$m1,'Monitor')} = $monitors->{$key}{'monitor'};
		if ($monitors->{$key}{'monitor-mapped'}){
			$rows->[$$j]{main::key($$num++,0,$m2,'mapped')} = $monitors->{$key}{'monitor-mapped'};
		}
		if ($monitors->{$key}{'disabled'}){
			$rows->[$$j]{main::key($$num++,0,$m2,'note')} = $monitors->{$key}{'disabled'};
		}
		if ($monitors->{$key}{'position'}){
			$rows->[$$j]{main::key($$num++,0,$m2,'pos')} = $monitors->{$key}{'position'};
		}
		if ($monitors->{$key}{'model'}){
			$rows->[$$j]{main::key($$num++,0,$m2,'model')} = $monitors->{$key}{'model'};
		}
		elsif ($monitors->{$key}{'model-id'}){
			$rows->[$$j]{main::key($$num++,0,$m2,'model-id')} = $monitors->{$key}{'model-id'};
		}
		if ($extra > 2 && $monitors->{$key}{'serial'}){
			$rows->[$$j]{main::key($$num++,0,$m2,'serial')} = main::filter($monitors->{$key}{'serial'});
		}
		if ($b_admin && $monitors->{$key}{'build-date'}){
			$rows->[$$j]{main::key($$num++,0,$m2,'built')} = $monitors->{$key}{'build-date'};
		}
		if ($monitors->{$key}{'res-x'} || $monitors->{$key}{'res-y'} || 
		$monitors->{$key}{'hz'} || $monitors->{$key}{'size-x'} || 
		$monitors->{$key}{'size-y'}){
			if ($monitors->{$key}{'res-x'} && $monitors->{$key}{'res-y'}){
				$resolution = $monitors->{$key}{'res-x'} . 'x' . $monitors->{$key}{'res-y'};
			}
			$resolution ||= 'N/A';
			$rows->[$$j]{main::key($$num++,0,$m2,'res')} = $resolution;
		}
		else {
			if ($b_display){
				$resolution = main::message('monitor-na');
			}
			else {
				$resolution = main::message('monitor-console');
			}
			$b_no_size = 1;
			$rows->[$$j]{main::key($$num++,0,$m2,'size-res')} = $resolution;
		}
		if ($extra > 2 && $monitors->{$key}{'hz'}){
			$rows->[$$j]{main::key($$num++,0,$m2,'hz')} = $monitors->{$key}{'hz'};
		}
		if ($monitors->{$key}{'dpi'}){
			$rows->[$$j]{main::key($$num++,0,$m2,'dpi')} = $monitors->{$key}{'dpi'};
		}
		if ($b_admin && $monitors->{$key}{'gamma'}){
			$rows->[$$j]{main::key($$num++,0,$m2,'gamma')} = $monitors->{$key}{'gamma'};
		}
		if ($show{'edid'} && $monitors->{$key}{'colors'}){
			$rows->[$$j]{main::key($$num++,1,$m2,'chroma')} = '';
			$rows->[$$j]{main::key($$num++,1,$m3,'red')} = '';
			$rows->[$$j]{main::key($$num++,0,$m4,'x')} = $monitors->{$key}{'colors'}{'red_x'};
			$rows->[$$j]{main::key($$num++,0,$m4,'y')} = $monitors->{$key}{'colors'}{'red_y'};
			$rows->[$$j]{main::key($$num++,1,$m3,'green')} = '';
			$rows->[$$j]{main::key($$num++,0,$m4,'x')} = $monitors->{$key}{'colors'}{'green_x'};
			$rows->[$$j]{main::key($$num++,0,$m4,'y')} = $monitors->{$key}{'colors'}{'green_y'};
			$rows->[$$j]{main::key($$num++,1,$m3,'blue')} = '';
			$rows->[$$j]{main::key($$num++,0,$m4,'x')} = $monitors->{$key}{'colors'}{'blue_x'};
			$rows->[$$j]{main::key($$num++,0,$m4,'y')} = $monitors->{$key}{'colors'}{'blue_y'};
			$rows->[$$j]{main::key($$num++,1,$m3,'white')} = '';
			$rows->[$$j]{main::key($$num++,0,$m4,'x')} = $monitors->{$key}{'colors'}{'white_x'};
			$rows->[$$j]{main::key($$num++,0,$m4,'y')} = $monitors->{$key}{'colors'}{'white_y'};
		}
		if ($extra > 2 && $monitors->{$key}{'scale'}){
			$rows->[$$j]{main::key($$num++,0,$m2,'scale')} = $monitors->{$key}{'scale'};
		}
		if ($extra > 2 && $monitors->{$key}{'size-x'} && $monitors->{$key}{'size-y'}){
			my $size =  $monitors->{$key}{'size-x'} . 'x' . $monitors->{$key}{'size-y'} .
			'mm ('. $monitors->{$key}{'size-x-i'} . 'x' . $monitors->{$key}{'size-y-i'} . '")';
			$rows->[$$j]{main::key($$num++,0,$m2,'size')} = $size;
		}
		if ($monitors->{$key}{'diagonal'}){
			my $diag = $monitors->{$key}{'diagonal-m'} . 'mm ('. $monitors->{$key}{'diagonal'} . '")';
			$rows->[$$j]{main::key($$num++,0,$m2,'diag')} = $diag;
		}
		elsif ($b_display && !$b_no_size && !$monitors->{$key}{'size-x'} && 
		!$monitors->{$key}{'size-y'}){
			$rows->[$$j]{main::key($$num++,0,$m2,'size')} = main::message('monitor-na');;
		}
		if ($b_admin && $monitors->{$key}{'ratio'}){
			$rows->[$$j]{main::key($$num++,0,$m2,'ratio')} = $monitors->{$key}{'ratio'};
		}
		if ($extra > 2){
			if (!$monitors->{$key}{'modes'} || !@{$monitors->{$key}{'modes'}}){
				$monitors->{$key}{'modes'} = ['N/A'];
			}
			my $cnt = scalar @{$monitors->{$key}{'modes'}};
			if ($cnt == 1 || ($cnt > 2 && $show{'edid'})){
				$rows->[$$j]{main::key($$num++,0,$m2,'modes')} = join(', ', @{$monitors->{$key}{'modes'}});
			}
			else {
				$rows->[$$j]{main::key($$num++,1,$m2,'modes')} = '';
				$rows->[$$j]{main::key($$num++,0,$m3,'max')} = ${$monitors->{$key}{'modes'}}[0];
				$rows->[$$j]{main::key($$num++,0,$m3,'min')} = ${$monitors->{$key}{'modes'}}[-1];
			}
		}
		if ($show{'edid'}){
			if ($monitors->{$key}{'edid-errors'}){
				$$j++;
				my $cnt = 1;
				$rows->[$$j]{main::key($$num++,1,$m2,'EDID-Errors')} = '';
				foreach my $err (@{$monitors->{$key}{'edid-errors'}}){
					$rows->[$$j]{main::key($$num++,0,$m3,$cnt)} = $err;
					$cnt++;
				}
			}
			if ($monitors->{$key}{'edid-warnings'}){
				$$j++;
				my $cnt = 1;
				$rows->[$$j]{main::key($$num++,1,$m2,'EDID-Warnings')} = '';
				foreach my $warn (@{$monitors->{$key}{'edid-warnings'}}){
					$rows->[$$j]{main::key($$num++,0,$m3,$cnt)} = $warn;
					$cnt++;
				}
			}
		}
	}
	# we only want to see gpu drivers for wayland since otherwise it's x drivers.
# 	if ($b_display && $b_admin && $graphics{'protocol'} && 
# 	$graphics{'protocol'} eq 'wayland' && $monitors->{$key}{'drivers'}){
# 		$driver = join(',',@{$monitors->{$key}{'drivers'}});
# 		$rows->[$j]{main::key($$num++,0,$m2,'driver')} = $driver;
# 	}
	eval $end if $b_log;
}

## DISPLAY API ##

# API Output #

# GLX/OpenGL EGL Vulkan XVesa
sub display_api {
	eval $start if $b_log;
	my $rows = $_[0];
	# print ("$b_display : $b_root\n");
	# xvesa is absolute, if it's there, it works in or out of display
	if ($graphics{'xvesa'}){
		xvesa_output($rows);
		return;
	}
	my ($b_egl,$b_egl_print,$b_glx,$b_glx_print,$b_vulkan,$api,$program,$type);
	my $gl = {};
	if ($fake{'egl'} || ($program = main::check_program('eglinfo'))){
		gl_data('egl',$program,$rows,$gl);
		$b_egl = 1;
	}
	if ($fake{'glx'} || ($program = main::check_program('glxinfo'))){
		gl_data('glx',$program,$rows,$gl) if $b_display;
		$b_glx = 1;
	}
	# Note: we let gl/egl output handle null or root null data issues
	if ($gl->{'glx'}){
		process_glx_data($gl->{'glx'},$b_glx);
	}
	# egl/vulkan give data out of display, and for root
	# if ($b_egl}){
	if ($b_egl && ($show{'graphic-full'} || !$gl->{'glx'})){
		egl_output($rows,$gl);
		$b_egl_print = 1;
	}
	# fill in whatever was missing from eglinfo, or if legacy system/no eglinfo
	# if ($b_glx || $gl->{'glx'}){
	if (($show{'graphic-full'} && ($b_glx || $gl->{'glx'})) || 
	(!$show{'graphic-full'} && !$b_egl_print && ($b_glx || $gl->{'glx'}))){
		opengl_output($rows,$gl);
		$b_glx = 1;
		$b_glx_print = 1;
	}
	# if ($fake{'vulkan'} || ($program = main::check_program('vulkaninfo'))){
	if (($fake{'vulkan'} || ($program = main::check_program('vulkaninfo'))) &&
	($show{'graphic-full'} || (!$b_egl_print && !$b_glx_print))){
		vulkan_output($program,$rows);
		$b_vulkan = 1;
	}
	if ($show{'graphic-full'} || (!$b_egl_print && !$b_glx_print)){
		# remember, sudo/root usually has empty $DISPLAY as well
		if ($b_display){
			# first do positive tests, won't be set for sudo/root
			if (!$b_glx && $graphics{'protocol'} eq 'x11'){
				$api = 'OpenGL';
				$type = 'glx-missing';
			}
			elsif (!$b_egl && $graphics{'protocol'} eq 'wayland'){
				$api = 'EGL'; # /GBM
				$type = 'egl-missing';
			}
			elsif (!$b_glx && 
			(main::check_program('X') || main::check_program('Xorg'))){
				$api = 'OpenGL';
				$type = 'glx-missing';
			}
			elsif (!$b_egl && main::check_program('Xwayland')){
				$api = 'EGL';
				$type = 'egl-missing';
			}
			elsif (!$b_egl && !$b_glx && !$b_vulkan) {
				$api = 'N/A';
				$type = 'gfx-api';
			}
		}
		else {
			if (!$b_glx && 
			(main::check_program('X') || main::check_program('Xorg'))){
				$api = 'OpenGL';
				$type = 'glx-missing-console';
			}
			elsif (!$b_egl && main::check_program('Xwayland')){
				$api = 'EGL';
				$type = 'egl-missing-console';
			}
			# we don't know what it is, headless system, non xwayland wayland
			elsif (!$b_egl && !$b_glx && !$b_vulkan) {
				$api = 'N/A';
				$type = 'gfx-api-console';
			}
		}
		no_data_output($api,$type,$rows) if $type;
	}
	eval $end if $b_log;
}

sub no_data_output {
	eval $start if $b_log;
	my ($api,$type,$rows) = @_;
	my $num = 0;
	push(@$rows, {
	main::key($num++,1,1,'API') => $api,
	main::key($num++,0,2,'Message') => main::message($type)
	});
	eval $end if $b_log;
}

sub egl_output {
	eval $start if $b_log;
	my ($rows,$gl) = @_;
	if (!$gl->{'egl'}){
		my $api = 'EGL';
		my $type = 'egl-null';
		no_data_output($api,$type,$rows);
		return 0;
	}
	my ($i,$j,$num) = (0,scalar @$rows,0);
	my ($value);
	my $ref;
	my $data = $gl->{'egl'}{'data'};
	my $plat = $gl->{'egl'}{'platforms'};
	push(@$rows, {
	main::key($num++,1,1,'API') => 'EGL',
	});
	if ($extra < 2){
		$value = ($data->{'versions'}) ? join(',',sort keys %{$data->{'versions'}}): 'N/A';
	}
	else {
		$value = ($data->{'version'}) ? $data->{'version'}: 'N/A';
	}
	$rows->[$j]{main::key($num++,0,2,'v')} = $value;
	if ($extra < 2){
		$value = ($data->{'drivers'}) ? join(',',sort keys %{$data->{'drivers'}}): 'N/A';
		$rows->[$j]{main::key($num++,0,2,'drivers')} = $value;
		$value = ($data->{'platforms'}{'active'}) ? join(',',@{$data->{'platforms'}{'active'}}) : 'N/A';
		if ($extra < 1){
			$rows->[$j]{main::key($num++,0,2,'platforms')} = $value;
		}
		else {
			$rows->[$j]{main::key($num++,1,2,'platforms')} = '';
			$rows->[$j]{main::key($num++,0,3,'active')} = $value;
			$value = ($data->{'platforms'}{'inactive'}) ? join(',',@{$data->{'platforms'}{'inactive'}}) : 'N/A';
			$rows->[$j]{main::key($num++,0,3,'inactive')} = $value;
		}
	}
	else {
		if ($extra > 2 && $data->{'hw'}){
			$i = 0;
			$rows->[$j]{main::key($num++,1,2,'hw')} = '';
			foreach my $key (sort keys %{$data->{'hw'}}){
				$value = ($key ne $data->{'hw'}{$key}) ? $data->{'hw'}{$key} . ' ' . $key: $key;
				$rows->[$j]{main::key($num++,0,3,'drv')} = $value;
			}
		}
		$rows->[$j]{main::key($num++,1,2,'platforms')} = '';
		$data->{'version'} ||= 0;
		$i = 0;
		foreach my $key (sort keys %$plat){
			next if !$plat->{$key}{'status'} || $plat->{$key}{'status'} eq 'inactive';
			if ($key eq 'device'){
				foreach my $id (sort keys %{$plat->{$key}}){
					next if ref $plat->{$key}{$id} ne 'HASH';
					$rows->[$j]{main::key($num++,1,3,$key)} = $id;
					$ref = $plat->{$key}{$id}{'egl'};
					egl_advanced_output($rows,$ref,\$num,$j,4,$data->{'version'});
				}
			}
			else {
				$rows->[$j]{main::key($num++,1,3,$key)} = '';
				$ref = $plat->{$key}{'egl'};
				egl_advanced_output($rows,$ref,\$num,$j,4,$data->{'version'});
			}
		}
		if (!$data->{'platforms'}{'active'}){
			$rows->[$j]{main::key($num++,0,3,'active')} = 'N/A';
		}
		if ($data->{'platforms'}{'inactive'}){
			$rows->[$j]{main::key($num++,0,3,'inactive')} = join(',',@{$data->{'platforms'}{'inactive'}});
		}
	}
	eval $end if $b_log;
}

# args: 0: $rows; 1: data ref; 2: \$num; 3: $j; 4: indent; 5: $b_plat_v
sub egl_advanced_output {
	my ($rows,$ref,$num,$j,$ind,$version) = @_;
	my $value;
	# version is set to 0 for math
	if ($version && (!$ref->{'version'} || $version != $ref->{'version'})){
		$value = ($ref->{'version'}) ? $ref->{'version'} : 'N/A';
		$rows->[$j]{main::key($$num++,0,$ind,'egl')} = $value;
		undef $value;
	}
	if ($ref->{'driver'}){
		$value = $ref->{'driver'};
	}
	else {
		if ($ref->{'vendor'} && $ref->{'vendor'} ne 'mesa'){
			$value = $ref->{'vendor'};
		}
		$value ||= 'N/A';
	}
	$rows->[$j]{main::key($$num++,0,$ind,'drv')} = $value;
}

sub opengl_output {
	eval $start if $b_log;
	my ($rows,$gl) = @_;
	# egl will have set $glx if present
	if (!$gl->{'glx'}){
		my $api = 'OpenGL';
		my $type;
		if ($b_display){
			$type = ($b_root) ? 'glx-display-root': 'glx-null';
		}
		else {
			$type = ($b_root) ? 'glx-console-root' : 'glx-console-try';
		}
		no_data_output($api,$type,$rows);
		return 0;
	}
	my ($j,$num) = (scalar @$rows,0);
	my $value;
	# print join("\n", %$gl),"\n";
	my $glx = $gl->{'glx'};
	$glx->{'opengl'}{'version'} ||= 'N/A';
	push(@$rows, {
	main::key($num++,1,1,'API') => 'OpenGL',
	main::key($num++,0,2,'v') => $glx->{'opengl'}{'version'},
	});
	if ($glx->{'opengl'}{'compatibility'}{'version'}){
		$rows->[$j]{main::key($num++,0,2,'compat-v')} = $glx->{'opengl'}{'compatibility'}{'version'};
	}
	if ($glx->{'opengl'}{'vendor'}){
		$rows->[$j]{main::key($num++,1,2,'vendor')} = $glx->{'opengl'}{'vendor'};
		$glx->{'opengl'}{'driver'}{'version'} ||= 'N/A';
		$rows->[$j]{main::key($num++,0,3,'v')} = $glx->{'opengl'}{'driver'}{'version'};
	}
	if ($extra > 0 && $glx->{'glx-version'}){
		$rows->[$j]{main::key($num++,0,2,'glx-v')} = $glx->{'glx-version'};
	}
	if ($extra > 1 && $glx->{'es'}{'version'}){
		$rows->[$j]{main::key($num++,0,2,'es-v')} = $glx->{'es'}{'version'};;
	}
	if ($glx->{'note'}){
		$rows->[$j]{main::key($num++,0,2,'note')} = $glx->{'note'};
	}
	if ($extra > 0 && (!$glx->{'note'} || $glx->{'direct-render'})){
		$glx->{'direct-render'} ||= 'N/A';
		$rows->[$j]{main::key($num++,0,2,'direct-render')} = $glx->{'direct-render'};
	}
	if (!$glx->{'note'} || $glx->{'opengl'}{'renderer'}){
		$glx->{'opengl'}{'renderer'} ||= 'N/A';
		$rows->[$j]{main::key($num++,0,2,'renderer')} = $glx->{'opengl'}{'renderer'};
	}
	if ($extra > 1 && $glx->{'info'}){
		if ($glx->{'info'}{'vendor-id'} && $glx->{'info'}{'device-id'}){
			$value = $glx->{'info'}{'vendor-id'} . ':' . $glx->{'info'}{'device-id'};
			$rows->[$j]{main::key($num++,0,2,'device-ID')} = $value;
		}
		if ($b_admin && $glx->{'info'}{'device-memory'}){
			$rows->[$j]{main::key($num++,1,2,'memory')} = $glx->{'info'}{'device-memory'};
			if ($glx->{'info'}{'unified-memory'}){
				$rows->[$j]{main::key($num++,0,3,'unified')} = $glx->{'info'}{'unified-memory'};
			}
		}
		# display id depends on xdpyinfo in Display line, which may not be present, 
		if (!$graphics{'display-id'} && $glx->{'display-id'} && $extra > 1){
			$rows->[$j]{main::key($num++,0,2,'display-ID')} = $glx->{'display-id'};
		}
	}
	eval $end if $b_log;
}

sub vulkan_output {
	eval $start if $b_log;
	my ($program,$rows) = @_;
	my $vulkan = {};
	vulkan_data($program,$vulkan);
	if (!%$vulkan){
		my $api = 'Vulkan';
		my $type = 'vulkan-null';
		no_data_output($api,$type,$rows);
		return 0;
	}
	my $num = 0;
	my $j = scalar @$rows;
	my ($value);
	my $data = $vulkan->{'data'};
	my $devices = $vulkan->{'devices'};
	$data->{'version'} ||= 'N/A';
	push(@$rows,{
	main::key($num++,1,1,'API') => 'Vulkan',
	main::key($num++,0,2,'v') => $data->{'version'},
	});
	# this will be expanded with -a to a full device report
	if ($extra < 2){
		$value = ($data->{'drivers'}) ? join(',',@{$data->{'drivers'}}): 'N/A';
		$rows->[$j]{main::key($num++,0,2,'drivers')} = $value;
	}
	if ($extra > 2){
		$data->{'layers'} ||= 'N/A';
		$rows->[$j]{main::key($num++,0,2,'layers')} = $data->{'layers'};
	}
	if (!$b_admin){
		$value = ($data->{'surfaces'}) ? join(',',@{$data->{'surfaces'}}) : 'N/A';
		$rows->[$j]{main::key($num++,0,2,'surfaces')} = $value;
	}
	if ($extra > 0){
		if (!$devices){
			$rows->[$j]{main::key($num++,0,2,'devices')} = 'N/A';
		}
		else {
			if ($extra < 2){
				$value = scalar keys %{$devices};
				$rows->[$j]{main::key($num++,0,2,'devices')} = $value;
			}
			else {
				foreach my $id (sort keys %$devices){
					$rows->[$j]{main::key($num++,1,2,'device')} = $id;
					$devices->{$id}{'device-type'} ||= 'N/A';
					$rows->[$j]{main::key($num++,0,3,'type')} = $devices->{$id}{'device-type'};
					if ((($extra == 3 && !$b_admin) || 
					($extra > 2 && !$devices->{$id}{'device-name'})) && 
					$devices->{$id}{'hw'} && $devices->{$id}{'hw'} ne 'nvidia'){
						$rows->[$j]{main::key($num++,0,3,'hw')} = $devices->{$id}{'hw'};
					}
					if ($b_admin){
						$value = ($devices->{$id}{'device-name'}) ? 
						$devices->{$id}{'device-name'}: 'N/A';
						$rows->[$j]{main::key($num++,0,3,'name')} = $value;
					}
					if ($extra > 1){
						if ($devices->{$id}{'driver-name'}){
							$value = $devices->{$id}{'driver-name'};
							if ($devices->{$id}{'mesa'} && $value ne 'mesa'){
								$value = 'mesa ' . $value;
							}
							$rows->[$j]{main::key($num++,1,3,'driver')} = $value;
							if ($b_admin && $devices->{$id}{'driver-info'}){
								$rows->[$j]{main::key($num++,0,4,'v')} = $devices->{$id}{'driver-info'};
							}
						}
						else {
							$rows->[$j]{main::key($num++,0,3,'driver')} = 'N/A';
						}
						$value = ($devices->{$id}{'device-id'} && $devices->{$id}{'vendor-id'}) ? 
						$devices->{$id}{'vendor-id'} . ':' . $devices->{$id}{'device-id'} : 'N/A';
						$rows->[$j]{main::key($num++,0,3,'device-ID')} = $value;
						if ($b_admin){
							$value = ($devices->{$id}{'surfaces'}) ? 
							join(',',@{$devices->{$id}{'surfaces'}}): 'N/A';
							$rows->[$j]{main::key($num++,0,3,'surfaces')} = $value;
						}
					}
				}
			}
		}
	}
	eval $end if $b_log;
}

sub xvesa_output {
	eval $start if $b_log;
	my ($rows) = @_;
	my ($controller,$dac,$interface,$ram,$source,$version);
	# note: goes to stderr, not stdout
	my @data = main::grabber($graphics{'xvesa'} . ' -listmodes 2>&1');
	my $j = scalar @$rows;
	my $num = 0;
	# gop replaced uga, both for uefi
	# WARNING! Never seen a GOP type UEFI, needs more data
	if ($data[0] && $data[0] =~ /^(VBE|GOP|UGA)\s+version\s+(\S+)\s\(([^)]+)\)/i){
		$interface = $1;
		$version = $2;
		$source = $3;
	}
	if ($data[1] && $data[1] =~ /^DAC is ([^,]+), controller is ([^,]+)/i){
		$dac = $1;
		$controller = $2;
	}
	if ($data[2] && $data[2] =~ /^Total memory:\s+(\d+)\s/i){
		$ram = $1;
		$ram = main::get_size($ram,'string');
	}
	if (!$interface){
		$rows->[$j]{main::key($num++,1,1,'API')} = 'VBE/GOP';
		$rows->[$j]{main::key($num++,0,2,'Message')} = main::message('xvesa-null');
	}
	else {
		$rows->[$j]{main::key($num++,1,1,'API')} = $interface;
		$rows->[$j]{main::key($num++,0,2,'v')} = ($version) ? $version : 'N/A';
		$rows->[$j]{main::key($num++,0,2,'source')} = ($source) ? $source : 'N/A';
		if ($dac){
			$rows->[$j]{main::key($num++,0,2,'dac')} = $dac;
			$rows->[$j]{main::key($num++,0,2,'controller')} = $controller;
		}
		if ($ram){
			$rows->[$j]{main::key($num++,0,2,'ram')} = $ram;
		}
	}
	eval $end if $b_log;
}

# API Data #
sub gl_data {
	eval $start if $b_log;
	my ($source,$program,$rows,$gl) = @_;
	my ($b_opengl,$msg);
	my ($gl_data,$results) = ([],[]);
	# only check these if no eglinfo or eglinfo had no opengl data
	$b_opengl = 1 if ($source eq 'egl' || !$gl->{'glx'});
	# NOTE: glxinfo -B is not always available, unfortunately
	if ($dbg[56] || $b_log){
		$msg = "${line1}GL Source: $source\n${line3}";
		print $msg if $dbg[56];
		push(@$results,$msg) if $b_log;
	}
	if ($source eq 'glx'){
		if (!$fake{'glx'}){
			$gl_data = main::grabber("$program $display_opt 2>/dev/null",'','','ref');
		}
		else {
			my $file;
			# $file = "$fake_data_dir/graphics/glxinfo/glxinfo-2012-nvidia-glx1.4.txt";
			# $file = "$fake_data_dir/graphics/glxinfo/glxinfo-ssh-centos.txt";
			# $file = "$fake_data_dir/graphics/glxinfo/glxiinfo-t420-intel-1.txt";
			# $file = "$fake_data_dir/graphics/glxinfo/glxinfo-mali-allwinner-lima-1.txt";
			# $file = "$fake_data_dir/graphics/glxinfo/glxinfo-partial-intel-5500-1.txt";
			# $file = "$fake_data_dir/graphics/glxinfo/glxinfo-vbox-debian-etch-1.txt";
			# $file = "$fake_data_dir/graphics/glxinfo/glxinfo-x11-neomagic-lenny-1.txt";
			# $file = "$fake_data_dir/graphics/glxinfo/glxinfo-nvidia-gl4.6-chr.txt";
			# $file = "$fake_data_dir/graphics/glxinfo/glxinfo-intel-atom-dell_studio-bm.txt";
			# $file = "$fake_data_dir/graphics/glxinfo/glxinfo-asus_1025c-atom-bm.txt";
			# $file = "$fake_data_dir/graphics/glxinfo/glxinfo-2011-nvidia-glx1.4.txt";
			$gl_data= main::reader($file,'','ref');
		}
	}
	else {
		if (!$fake{'egl'}){
			$gl_data = main::grabber("$program 2>/dev/null",'','','ref');
		}
		else {
			my $file;
			# $file = "$fake_data_dir/graphics/egl-es/eglinfo-x11-3.txt";
			# $file = "$fake_data_dir/graphics/egl-es/eglinfo-wayland-intel-c30.txt";
			# $file = "$fake_data_dir/grapOhics/egl-es/eglinfo-2022-x11-nvidia-egl1.5.txt";
			# $file = "$fake_data_dir/graphics/egl-es/eglinfo-wayland-intel-nvidia-radu.txt";
			# $file = "$fake_data_dir/graphics/egl-es/eglinfo-intel-atom-dell_studio-bm.txt";
			# $file = "$fake_data_dir/graphics/egl-es/eglinfo-asus_1025c-atom-bm.txt";
			# $file = "$fake_data_dir/graphics/egl-es/eglinfo-x11-amd-raphael-1.txt";
			 $file = "$fake_data_dir/graphics/egl-es/eglinfo-x11-vm-version-odd.txt";
			$gl_data = main::reader($file,'','ref');
		}
	}
	# print join("\n", @$gl_data),"\n";
	if (!$gl_data || !@$gl_data){
		if ($dbg[56] || $b_log){
			$msg = "No data found for GL Source: $source" if $dbg[56];
			print "$msg\n" if $dbg[56];
			push(@$results,$msg) if $b_log;
		}
		return 0;
	}
	# some error cases have only a few top value but not empty
	elsif ($source eq 'glx' && scalar @$gl_data > 5){
		$gl->{'glx'}{'source'} = $source;
	}
	set_mesa_drivers() if $source eq 'egl' && !%mesa_drivers;
	my ($b_device,$b_platform,$b_mem_info,$b_rend_info,$device,$platform,
	$value,$value2,@working);
	foreach my $line (@$gl_data){
		next if (!$b_rend_info && !$b_mem_info) && $line =~ /^(\s|0x)/;
		if (($b_rend_info || $b_mem_info) && $line =~ /^\S/){
			($b_mem_info,$b_rend_info) = ();
		}
		@working = split(/\s*:\s*/,$line,2);
		next if !@working;
		if ($dbg[56] || $b_log){
			$msg = $line;
			print "$msg\n" if $dbg[56];
			push(@$results,$msg) if $b_log;
		}
		if ($source eq 'egl'){
			# eglinfo: eglInitialize failed
			# This is first line after platform fail for devices, but for Device 
			# it would be the second or later line. The Device platform can fail, or 
			# specific device can fail
			if ($b_platform){
				$value = ($line =~ /Initialize failed/) ? 'inactive': 'active';
				push(@{$gl->{'egl'}{'data'}{'platforms'}{$value}},$platform);
				$gl->{'egl'}{'platforms'}{$platform}{'status'} = $value;
				$b_platform = 0;
			}
			# note: can be sub item: Platform Device platform:; Platform Device:
			elsif ($working[0] =~ /^(\S+) platform/i){
				$platform = lc($1);
				undef $device;
				$b_platform = 1;
			}
			if ($platform && defined $device && $working[0] eq 'eglinfo'){
				push(@{$gl->{'egl'}{'data'}{'platforms'}{'inactive'}},"$platform-$device");
				undef $device;
			}
			if ($platform && $platform eq 'device' && $working[0] =~ /^Device #(\d+)/){
				$device = $1;
			}
			if ($working[0] eq 'EGL API version'){
				if (!defined $platform){
					$gl->{'egl'}{'data'}{'api-version'} = $working[1];
				}
				elsif (defined $device){ 
					$gl->{'egl'}{'platforms'}{$platform}{$device}{'egl'}{'api-version'} = $working[1];
				}
				else {
					$gl->{'egl'}{'platforms'}{$platform}{'egl'}{'api-version'} = $working[1];
				}
			}
			elsif ($working[0] eq 'EGL version string'){
				# seen case of: 1.4 (DRI2)
				$working[1] =~ s/^([\d\.]+)(\s.*)?/$1/;
				if (!defined $platform){
					$gl->{'egl'}{'data'}{'version'} = $working[1];
				}
				elsif (defined $device){ 
					$gl->{'egl'}{'platforms'}{$platform}{$device}{'egl'}{'version'} = $working[1];
				}
				else {
					$gl->{'egl'}{'platforms'}{$platform}{'egl'}{'version'} = $working[1];
				}
				$value = (defined $device) ? "$platform-$device": $platform;
				push(@{$gl->{'egl'}{'data'}{'versions'}{$working[1]}},$value);
				if (!$gl->{'egl'}{'data'}{'version'} || 
				$working[1] > $gl->{'egl'}{'data'}{'version'}){
					$gl->{'egl'}{'data'}{'version'} = $working[1];
				}
			}
			elsif ($working[0] eq 'EGL vendor string'){
				$working[1] = lc($working[1]);
				$working[1] =~ s/^(\S+)(\s.+|$)/$1/;
				if (!defined $platform){
					$gl->{'egl'}{'data'}{'vendor'} = $working[1];
				}
				elsif (defined $device){ 
					$gl->{'egl'}{'platforms'}{$platform}{$device}{'egl'}{'vendor'} = $working[1];
					if ($working[1] eq 'nvidia'){
						$gl->{'egl'}{'platforms'}{$platform}{$device}{'egl'}{'driver'} = $working[1];
					}
				}
				else {
					$gl->{'egl'}{'platforms'}{$platform}{'egl'}{'vendor'} = $working[1];
					if ($working[1] eq 'nvidia'){
						$gl->{'egl'}{'platforms'}{$platform}{'egl'}{'driver'} = $working[1];
					}
				}
				push(@{$gl->{'egl'}{'data'}{'vendors'}},$working[1]);
				if ($platform && $working[1] eq 'nvidia'){
					$value = (defined $device) ? "$platform-$device": $platform;
					push(@{$gl->{'egl'}{'data'}{'drivers'}{$working[1]}},$value);
					$gl->{'egl'}{'data'}{'hw'}{$working[1]} = $working[1];
				}
			}
			elsif ($platform && $working[0] eq 'EGL driver name'){
				if (!defined $device){ 
					$gl->{'egl'}{'platforms'}{$platform}{'egl'}{'driver'} = $working[1];
					if ($mesa_drivers{$working[1]}){
						$gl->{'egl'}{'platforms'}{$platform}{'egl'}{'hw'} = $mesa_drivers{$working[1]};
					}
				}
				else {
					$gl->{'egl'}{'platforms'}{$platform}{$device}{'egl'}{'driver'} = $working[1];
					if ($mesa_drivers{$working[1]}){
						$gl->{'egl'}{'platforms'}{$platform}{$device}{'egl'}{'hw'} = $mesa_drivers{$working[1]};
					}
				}
				$value = (defined $device) ? "$platform-$device": $platform;
				push(@{$gl->{'egl'}{'data'}{'drivers'}{$working[1]}},$value);
				if ($mesa_drivers{$working[1]}){
					$gl->{'egl'}{'data'}{'hw'}{$working[1]} = $mesa_drivers{$working[1]};
				}
			}
			if ($platform && $working[0] eq 'EGL client APIs'){
				if (defined $device){ 
					$gl->{'egl'}{'platforms'}{$platform}{$device}{'egl'}{'client-apis'} = [split(/\s+/,$working[1])];
				}
				else {
					$gl->{'egl'}{'platforms'}{$platform}{'egl'}{'client-apis'} = [split(/\s+/,$working[1])];
				}
			}
		}
		# glx specific values, only found in glxinfo
		else {
			if (lc($working[0]) eq 'direct rendering'){
				$working[1] = lc($working[1]);
				if (!$gl->{'glx'}{'direct-renderers'} || 
				!(grep {$_ eq $working[1]} @{$gl->{'glx'}{'direct-renders'}})){
					push(@{$gl->{'glx'}{'direct-renders'}}, $working[1]);
				}
			}
			# name of display: does not always list the screen number
			elsif (lc($working[0]) eq 'display'){
				if ($working[1] =~ /^(:\d+)\s+screen:\s+(\d+)/){
					$gl->{'glx'}{'display-id'} = $1 . '.' . $2; 
				}
			}
			elsif (lc($working[0]) eq 'glx version'){
				if (!$gl->{'glx'}{'glx-version'}){
					$gl->{'glx'}{'glx-version'} = $working[1];
				}
			}
			elsif (!$b_rend_info && $working[0] =~ /^Extended renderer info/i){
				$b_rend_info = 1;
			}
			# only check Memory info if no prior device memory found
			elsif (!$b_mem_info && $working[0] =~ /^Memory info/i){
				$b_mem_info = (!$gl->{'glx'}{'info'} || !$gl->{'glx'}{'info'}{'device-memory'}) ? 1 : 0;
			}
			elsif ($b_rend_info){
				if ($line =~ /^\s+Vendor:\s+.*?\(0x([\da-f]+)\)$/){
					$gl->{'glx'}{'info'}{'vendor-id'} = sprintf("%04s",$1);
				}
				elsif ($line =~ /^\s+Device:\s+.*?\(0x([\da-f]+)\)$/){
					$gl->{'glx'}{'info'}{'device-id'} = sprintf("%04s",$1);
				}
				elsif ($line =~ /^\s+Video memory:\s+(\d+\s?[MG]B)$/){
					my $size = main::translate_size($1);
					$gl->{'glx'}{'info'}{'device-memory'} = main::get_size($size,'string');
				}
				elsif ($line =~ /^\s+Unified memory:\s+(\S+)$/){
					$gl->{'glx'}{'info'}{'unified-memory'} = lc($1);
				}
			}
			elsif ($b_mem_info){
				# fallback, nvidia does not seem to have Extended renderer info 
				if ($line =~ /^\s+Dedicated video memory:\s+(\d+\s?[MG]B)$/){
					my $size = main::translate_size($1);
					$gl->{'glx'}{'info'}{'device-memory'} = main::get_size($size,'string');
					$b_mem_info = 0;
				}
				# we're in the wrong memory block! 
				elsif ($line =~ /^\s+(VBO|Texture)/){
					$b_mem_info = 0;
				}
			}
			elsif (lc($working[0]) eq 'opengl vendor string'){
				if ($working[1] =~ /^([^\s]+)(\s+\S+)?/){
					my $vendor = lc($1);
					$vendor =~ s/(^mesa\/|[\.,]$)//; # Seen Mesa/X.org
					if (!$gl->{'glx'}{'opengl'}{'vendor'}){
						$gl->{'glx'}{'opengl'}{'vendor'} = $vendor;
					}
				}
			}
			elsif (lc($working[0]) eq 'opengl renderer string'){
				if ($working[1]){
					$working[1] = main::clean($working[1]);
				}
				# note: seen cases where gl drivers are missing, with empty field value.
				else {
					$gl->{'glx'}{'no-gl'} = 1;
					$working[1] = main::message('glx-value-empty');
				}
				if (!$gl->{'glx'}{'opengl'}{'renderers'} || 
				!(grep {$_ eq $working[1]} @{$gl->{'glx'}{'opengl'}{'renderers'}})){
					push(@{$gl->{'glx'}{'opengl'}{'renderers'}}, $working[1]) ;
				}
			}
			# Dropping all conditions from this test to just show full mesa information
			# there is a user case where not f and mesa apply, atom mobo
			# This can be the compatibility version, or just the version the hardware
			# supports. Core version will override always if present.
			elsif (lc($working[0]) eq 'opengl version string'){
				if ($working[1]){
					# first grab the actual gl version
					# non free drivers like nvidia may only show their driver version info 
					if ($working[1] =~ /^(\S+)(\s|$)/){
						push(@{$gl->{'glx'}{'opengl'}{'versions'}}, $1);
					}
					# handle legacy format: 1.2 (1.5 Mesa 6.5.1) as well as more current:
					# 4.5 (Compatibility Profile) Mesa 22.3.6
					# Note: legacy: fglrx starting adding compat strings but they don't
					# change this result:
					# 4.5 Compatibility Profile Context Mesa 15.3.6
					if ($working[1] =~ /(Mesa|NVIDIA)\s(\S+?)\)?$/i){
						if ($1 && $2 && !$gl->{'glx'}{'opengl'}{'driver'}){
							$gl->{'glx'}{'opengl'}{'driver'}{'vendor'} = lc($1);
							$gl->{'glx'}{'opengl'}{'driver'}{'version'} = $2;
						}
					}
				}
				elsif (!$gl->{'glx'}{'no-gl'}){
					$gl->{'glx'}{'no-gl'} = 1;
					push(@{$gl->{'glx'}{'opengl'}{'versions'}},main::message('glx-value-empty'));
				}
			}
			# if -B was always available, we could skip this, but it is not
			elsif ($line =~ /GLX Visuals/){
				last;
			}
		}
		# eglinfo/glxinfo share these
		if ($b_opengl){
			if ($working[0] =~ /^OpenGL (compatibility|core) profile version( string)?$/){
				$value = lc($1);
				# note: no need to apply empty message here since we don't have the data
				# anyway
				if ($working[1]){
					# non free drivers like nvidia only show their driver version info
					if ($working[1] =~ /^(\S+)(\s|$)/){
						push(@{$gl->{'glx'}{'opengl'}{$value}{'versions'}}, $1);
					}
					# fglrx started appearing with this extra string, does not appear 
					# to communicate anything of value
					if ($working[1] =~ /\s+(Mesa|NVIDIA)\s+(\S+)$/){
						if ($1 && $2 && !$gl->{'glx'}{'opengl'}{$value}{'vendor'}){
							$gl->{'glx'}{'opengl'}{$value}{'driver'}{'vendor'} = lc($1);
							$gl->{'glx'}{'opengl'}{$value}{'driver'}{'version'} = $2;
						}
						if ($source eq 'egl' && $platform){
							if (defined $device){
								$gl->{'egl'}{'platforms'}{$platform}{$device}{'opengl'}{$value}{'vendor'} = lc($1);
								$gl->{'egl'}{'platforms'}{$platform}{$device}{'opengl'}{$value}{'version'} = $2;
							}
							else {
								$gl->{'egl'}{'platforms'}{$platform}{'opengl'}{$value}{'vendor'} = lc($1);
								$gl->{'egl'}{'platforms'}{$platform}{'opengl'}{$value}{'version'} = $2;
							}
						}
					}
				}
			}
			elsif ($working[0] =~ /^OpenGL (compatibility|core) profile renderer?$/){
				$value = lc($1);
				if ($working[1]){
					$working[1] = main::clean($working[1]);
				}
				# note: seen cases where gl drivers are missing, with empty field value.
				else {
					$gl->{'glx'}{'no-gl'} = 1;
					$working[1] = main::message('glx-value-empty');
				}
				if (!$gl->{'glx'}{'opengl'}{$value}{'renderers'} || 
				!(grep {$_ eq $working[1]} @{$gl->{'glx'}{'opengl'}{$value}{'renderers'}})){
					push(@{$gl->{'glx'}{'opengl'}{$value}{'renderers'}}, $working[1]) ;
				}
				if ($source eq 'egl' && $platform){
					if ($value eq 'core'){
						$value2 = (defined $device) ? "$platform-$device": $platform;
						push(@{$gl->{'egl'}{'data'}{'renderers'}{$working[1]}},$value2);
					}
					if (defined $device){
						$gl->{'egl'}{'platforms'}{$platform}{$device}{'opengl'}{$value}{'renderer'} = $working[1];
					}
					else {
						$gl->{'egl'}{'platforms'}{$platform}{'opengl'}{$value}{'renderer'} = $working[1];
					}
				}
			}
			elsif ($working[0] =~ /^OpenGL (compatibility|core) profile vendor$/){
				$value = lc($1);
				if (!$gl->{'glx'}{'opengl'}{$value}{'vendors'} || 
				!(grep {$_ eq $working[1]} @{$gl->{'glx'}{'opengl'}{$value}{'vendors'}})){
					push(@{$gl->{'glx'}{'opengl'}{$value}{'vendors'}}, $working[1]) ;
				}
				if ($source eq 'egl' && $platform){
					if (defined $device){
						$gl->{'egl'}{'platforms'}{$platform}{$device}{'opengl'}{$value}{'vendor'} = $working[1];
					}
					else {
						$gl->{'egl'}{'platforms'}{$platform}{'opengl'}{$value}{'vendor'} = $working[1];
					}
					
				}
			}
			elsif (lc($working[0]) eq 'opengl es profile version string'){
				if ($working[1] && !$gl->{'glx'}{'es-version'}){
					# OpenGL ES 3.2 Mesa 23.0.3
					if ($working[1] =~ /^OpenGL ES (\S+) Mesa (\S+)/){
						$gl->{'glx'}{'es'}{'version'} = $1;
						if ($2 && !$gl->{'glx'}{'es'}{'mesa-version'}){
							$gl->{'glx'}{'es'}{'mesa-version'} = $2;
						}
						if ($source eq 'egl' && $platform){
							if (defined $device){
								$gl->{'egl'}{'platforms'}{$platform}{$device}{'opengl'}{'es'}{'vendor'} = 'mesa';
								$gl->{'egl'}{'platforms'}{$platform}{$device}{'opengl'}{'es'}{'version'} = $working[1];
							}
							else {
								$gl->{'egl'}{'platforms'}{$platform}{'opengl'}{'es'}{'vendor'} = 'mesa';
								$gl->{'egl'}{'platforms'}{$platform}{'opengl'}{'es'}{'version'} = $working[1];
							}
						}
					}
				}
			}
		}
	}
	main::log_data('dump',"$source \$results",$results) if $b_log;
	if ($source eq 'egl'){
		print "GL Data: $source: ", Data::Dumper::Dumper $gl if $dbg[57];
		main::log_data('dump',"GL data: $source:",$gl) if $b_log;
	}
	else {
		print "GL Data: $source: ", Data::Dumper::Dumper $gl->{'glx'} if $dbg[57];
		main::log_data('dump',"GLX data: $source:",$gl->{'glx'}) if $b_log;
	}
	eval $end if $b_log;
}

sub process_glx_data {
	eval $start if $b_log;
	my ($glx,$b_glx) = @_;
	my $value;
	# Remember: if you test for a hash ref hash ref, you create the first hash ref!
	if ($glx->{'direct-renders'}){
		$glx->{'direct-render'} = join(', ',  @{$glx->{'direct-renders'}});
	}
	if (!$glx->{'opengl'}{'renderers'} && $glx->{'opengl'}{'compatibility'} &&
	$glx->{'opengl'}{'compatibility'}{'renderers'}){
		$glx->{'opengl'}{'renderers'} = $glx->{'opengl'}{'compatibility'}{'renderers'};
	}
	# This is tricky, GLX OpenGL version string can be compatibility version,
	# but usually they are the same. Just in case, try this. Note these are 
	# x.y.z type numbering formats generally so use string compare
	if ($glx->{'opengl'}{'core'} && $glx->{'opengl'}{'core'}{'versions'}){
		$glx->{'opengl'}{'version'} = (sort @{$glx->{'opengl'}{'core'}{'versions'}})[-1];
	}
	elsif ($glx->{'opengl'}{'versions'}){
		$glx->{'opengl'}{'version'} = (sort @{$glx->{'opengl'}{'versions'}})[-1];
	}
	if ($glx->{'opengl'}{'version'} && 
	($glx->{'opengl'}{'compatibility'} || $glx->{'opengl'}{'versions'})){
		# print "v: $glx->{'opengl'}{'version'}\n";
		# print Data::Dumper::Dumper $glx->{'opengl'}{'versions'};
		# print 'v1: ', (sort @{$glx->{'opengl'}{'versions'}})[0], "\n";
		# here we look for different versions, and determine most likely compat one
		if ($glx->{'opengl'}{'compatibility'} && 
		$glx->{'opengl'}{'compatibility'}{'versions'} &&
		(sort @{$glx->{'opengl'}{'compatibility'}{'versions'}})[0] ne $glx->{'opengl'}{'version'}){
			$value = (sort @{$glx->{'opengl'}{'compatibility'}{'versions'}})[0];
			$glx->{'opengl'}{'compatibility'}{'version'} = $value;
		}
		elsif ($glx->{'opengl'}{'versions'} &&
		(sort @{$glx->{'opengl'}{'versions'}})[0] ne $glx->{'opengl'}{'version'}){
			$value = (sort @{$glx->{'opengl'}{'versions'}})[0];
			$glx->{'opengl'}{'compatibility'}{'version'} = $value;
		}
	}
	if ($glx->{'opengl'}{'renderers'}){
		$glx->{'opengl'}{'renderer'} = join(', ', @{$glx->{'opengl'}{'renderers'}});
	}
	# likely eglinfo or advanced glxinfo
	if ($glx->{'opengl'}{'vendor'} && 
	$glx->{'opengl'}{'core'} && 
	$glx->{'opengl'}{'core'}{'driver'} && 
	$glx->{'opengl'}{'core'}{'driver'}{'vendor'} && 
	$glx->{'opengl'}{'core'}{'driver'}{'vendor'} eq 'mesa' && 
	$glx->{'opengl'}{'vendor'} ne $glx->{'opengl'}{'core'}{'driver'}{'vendor'}){
		$value = $glx->{'opengl'}{'vendor'} . ' ';
		$value .= $glx->{'opengl'}{'core'}{'driver'}{'vendor'};
		$glx->{'opengl'}{'vendor'} = $value;
	}
	# this can be glxinfo only case, no eglinfo
	elsif ($glx->{'opengl'}{'vendor'} && 
	$glx->{'opengl'}{'driver'} && 
	$glx->{'opengl'}{'driver'}{'vendor'} && 
	$glx->{'opengl'}{'driver'}{'vendor'} eq 'mesa' && 
	$glx->{'opengl'}{'vendor'} ne $glx->{'opengl'}{'driver'}{'vendor'}){
		$value = $glx->{'opengl'}{'vendor'} . ' ';
		$value .= $glx->{'opengl'}{'driver'}{'vendor'};
		$glx->{'opengl'}{'vendor'} = $value;
	}
	elsif (!$glx->{'opengl'}{'vendor'} && 
	$glx->{'opengl'}{'core'}  && $glx->{'opengl'}{'core'}{'driver'} &&
	$glx->{'opengl'}{'core'}{'driver'}{'vendor'}){
		$glx->{'opengl'}{'vendor'} = $glx->{'opengl'}{'core'}{'driver'}{'vendor'};
	}
	if ((!$glx->{'opengl'}{'driver'} ||
	!$glx->{'opengl'}{'driver'}{'version'}) && 
	$glx->{'opengl'}{'core'} &&
	$glx->{'opengl'}{'core'}{'driver'} && 
	$glx->{'opengl'}{'core'}{'driver'}{'version'}){
		$value = $glx->{'opengl'}{'core'}{'driver'}{'version'};
		$glx->{'opengl'}{'driver'}{'version'} = $value;
	}
	# only tripped when glx filled by eglinfo
	if (!$glx->{'source'}){
		my $type;
		if (!$b_glx){
			$type = 'glx-egl-missing';
		}
		elsif ($b_display){
			$type = 'glx-egl';
		}
		else {
			$type = 'glx-egl-console';
		}
		$glx->{'note'} = main::message($type);
	}
	print "GLX Data: ", Data::Dumper::Dumper $glx if $dbg[57];
	main::log_data('dump',"GLX data:",$glx) if $b_log;
	eval $end if $b_log;
}

sub vulkan_data {
	eval $start if $b_log;
	my ($program,$vulkan) = @_;
	my ($data,$msg,@working);
	my ($results) = ([]);
	if ($dbg[56] || $b_log){
		$msg = "${line1}Vulkan Data\n${line3}";
		print $msg if $dbg[56];
		push(@$results,$msg) if $b_log;
	}
	if (!$fake{'vulkan'}){
		$data = main::grabber("$program 2>/dev/null",'','','ref');
	}
	else {
		my $file;
		 $file = "$fake_data_dir/graphics/vulkan/vulkaninfo-intel-llvm-1.txt";
		 $file = "$fake_data_dir/graphics/vulkan/vulkaninfo-nvidia-1.txt";
		 $file = "$fake_data_dir/graphics/vulkan/vulkaninfo-intel-1.txt";
		 $file = "$fake_data_dir/graphics/vulkan/vulkaninfo-amd-dz.txt";
		 $file = "$fake_data_dir/graphics/vulkan/vulkaninfo-mali-3.txt";
		$data = main::reader($file,'','ref');
	}
	if (!$data){
		if ($dbg[56] || $b_log){
			$msg = "No Vulkan data found" if $dbg[56];
			print "$msg\n" if $dbg[56];
			push(@$results,$msg) if $b_log;
		}
		return 0;
	}
	set_mesa_drivers() if !%mesa_drivers;
	my ($id,%active);
	foreach my $line (@$data){
		next if $line =~ /^(\s*|-+|=+)$/;
		@working = split(/\s*:\s*/,$line,2);
		next if !@working;
		if ($line =~ /^\S/){
			if ($active{'start'}){undef $active{'start'}}
			if ($active{'layers'}){undef $active{'layers'}}
			if ($active{'groups'}){undef $active{'groups'}}
			if ($active{'limits'}){undef $active{'limits'}}
			if ($active{'features'}){undef $active{'features'}}
			if ($active{'extensions'}){undef $active{'extensions'}}
			if ($active{'format'}){undef $active{'format'}}
			if ($active{'driver'}){($active{'driver'},$id) = ()}
		}
		next if $active{'start'};
		next if $active{'groups'};
		next if $active{'limits'};
		next if $active{'features'};
		next if $active{'extensions'};
		next if $active{'format'};
		if ($dbg[56] || $b_log){
			$msg = $line;
			print "$msg\n" if $dbg[56];
			push(@$results,$msg) if $b_log;
		}
		if ($working[0] eq 'Vulkan Instance Version'){
			$vulkan->{'data'}{'version'} = $working[1];
			$active{'start'} = 1;
		}
		elsif ($working[0] eq 'Layers'){
			if ($working[1] =~ /count\s*=\s*(\d+)/){
				$vulkan->{'data'}{'layers'} = $1;
			}
			$active{'layers'} = 1;
		}
		# note: can't close this because Intel didn't use proper indentation
		elsif ($working[0] eq 'Presentable Surfaces'){
			$active{'surfaces'} = 1;
		}
		elsif ($working[0] eq 'Device Groups'){
			$active{'groups'} = 1;
			$active{'surfaces'} = 0;
		}
		elsif ($working[0] eq 'Device Properties and Extensions'){
			$active{'devices'} = 1;
			$active{'surfaces'} = 0;
			undef $id;
		}
		elsif ($working[0] eq 'VkPhysicalDeviceProperties'){
			$active{'props'} = 1;
		}
		elsif ($working[0] eq 'VkPhysicalDeviceDriverProperties'){
			$active{'driver'} = 1;
		}
		elsif ($working[0] =~ /^\S+Features/i){
			$active{'features'} = 1;
		}
		# seen as line starter string or inner VkPhysicalDeviceProperties
		elsif ($working[0] =~ /^\s*\S+Limits/i){
			$active{'limits'} = 1;
		}
		elsif ($working[0] =~ /^FORMAT_/){
			$active{'format'} = 1;
		}
		elsif ($working[0] =~ /^(Device|Instance) Extensions/){
			$active{'extensions'} = 1;
		}
		if ($active{'surfaces'}){
			if ($working[0] eq 'GPU id'){
				if ($working[1] =~ /^(\d+)\s+\((.*?)\):?$/){
					$id = $1;
					$vulkan->{'devices'}{$id}{'model'} = main::clean($2);
				}
			}
			if (defined $id){
				# seen leading space, no leading space 
				if ($line =~ /^\s*Surface type/){
					$active{'surface-type'} = 1;
				}
				if ($active{'surface-type'} && $line =~ /\S+_(\S+)_surface$/){
					if (!$vulkan->{'devices'}{$id}{'surfaces'} || 
					!(grep {$_ eq $1} @{$vulkan->{'devices'}{$id}{'surfaces'}})){
						push(@{$vulkan->{'devices'}{$id}{'surfaces'}},$1);
					}
					if (!$vulkan->{'data'}{'surfaces'} || 
					!(grep {$_ eq $1} @{$vulkan->{'data'}{'surfaces'}})){
						push(@{$vulkan->{'data'}{'surfaces'}},$1);
					}
				}
				if ($working[0] =~ /^\s*Formats/){
					undef $active{'surface-type'};
				}
			}
		}
		if ($active{'devices'}){
			if ($working[0] =~ /^GPU(\d+)/){
				$id = $1;
			}
			elsif (defined $id){
				# apiVersion=4194528 (1.0.224); 1.3.246 (4206838); 79695971 (0x4c01063)
				if ($line =~ /^\s+apiVersion\s*=\s*(\S+)(\s+\(([^)]+)\))?/i){
					my ($a,$b) = ($1,$3);
					my $api = (!$b || $b =~ /^(0x)?\d+$/) ? $a : $b;
					$vulkan->{'devices'}{$id}{'device-api-version'} = $api;
				}
				elsif ($line =~ /^\s+driverVersion\s*=\s*(\S+)/i){
					$vulkan->{'devices'}{$id}{'device-driver-version'} = $1;
				}
				elsif ($line =~ /^\s+vendorID\s*=\s*0x(\S+)/i){
					$vulkan->{'devices'}{$id}{'vendor-id'} = $1;
				}
				elsif ($line =~ /^\s+deviceID\s*=\s*0x(\S+)/i){
					$vulkan->{'devices'}{$id}{'device-id'} = $1;
				}
				# deviceType=DISCRETE_GPU; PHYSICAL_DEVICE_TYPE_DISCRETE_GPU
				elsif ($line =~ /^\s+deviceType\s*=\s*(\S+?_TYPE_)?(\S+)$/i){
					$vulkan->{'devices'}{$id}{'device-type'} = lc($2);
					$vulkan->{'devices'}{$id}{'device-type'} =~ s/_/-/g;
				}
				# deviceName=AMD Radeon RX 6700 XT (RADV NAVI22); AMD RADV HAWAII
				# lvmpipe (LLVM 15.0.6, 256 bits); NVIDIA GeForce GTX 1650 Ti
				elsif ($line =~ /^\s+deviceName\s*=\s*(\S+)(\s.*|$)/i){
					$vulkan->{'devices'}{$id}{'device-vendor'} = main::clean(lc($1));
					$vulkan->{'devices'}{$id}{'device-name'} = main::clean($1 . $2);
				}
			}
		}
		if ($active{'driver'}){
			if (defined $id){
				# driverName=llvmpipe; radv; 
				if ($line =~ /^\s+driverName\s*=\s*(\S+)(\s|$)/i){
					my $driver = lc($1);
					if ($mesa_drivers{$driver}){
						$vulkan->{'devices'}{$id}{'hw'} = $mesa_drivers{$driver};
					}
					$vulkan->{'devices'}{$id}{'driver-name'} = $driver;
					if (!$vulkan->{'data'}{'drivers'} || 
					!(grep {$_ eq $driver} @{$vulkan->{'data'}{'drivers'}})){
						push(@{$vulkan->{'data'}{'drivers'}},$driver);
					}
				}
				# driverInfo=Mesa 23.1.3 (LLVM 15.0.7); 525.89.02; Mesa 23.1.3
				elsif ($line =~ /^\s+driverInfo\s*=\s*((Mesa)\s)?(.*)/i){
					$vulkan->{'devices'}{$id}{'mesa'} = lc($2) if $2;
					$vulkan->{'devices'}{$id}{'driver-info'} = $3;
				}
			}
		}
	}
	main::log_data('dump','$results',$results) if $b_log;
	print 'Vulkan Data: ', Data::Dumper::Dumper $vulkan if $dbg[57];
	main::log_data('dump','$vulkan',$vulkan) if $b_log;
	eval $end if $b_log;
}

## DISPLAY DATA WAYLAND ##
sub display_data_wayland {
	eval $start if $b_log;
	my ($b_skip_pos,$program);
	if ($ENV{'WAYLAND_DISPLAY'}){
		$graphics{'display-id'} = $ENV{'WAYLAND_DISPLAY'};
		# return as wayland-0 or 0?
		$graphics{'display-id'} =~ s/wayland-?//i;
	}
	if ($fake{'swaymsg'} || ($program = main::check_program('swaymsg'))){
		swaymsg_data($program);
	}
	# until we get data proving otherwise, assuming these have same output
	elsif ($fake{'wl-info'} || (($program = main::check_program('wayland-info')) || 
	($program = main::check_program('weston-info')))){
		wlinfo_data($program);
	}
	elsif ($fake{'wlr-randr'} || ($program = main::check_program('wlr-randr'))){
		wlrrandr_data($program);
	}
	# make sure we got enough for advanced position data, might be from /sys
	if ($extra > 1 && $monitor_ids){
		$b_skip_pos = check_wayland_data();
	}
	if ($extra > 1 && $monitor_ids && $b_wayland_data){
		# map_monitor_ids([keys %$monitors]); # not required, but leave in case.
		wayland_data_advanced($b_skip_pos);
	}
	print 'Wayland monitors: ', Data::Dumper::Dumper $monitor_ids if $dbg[17];
	main::log_data('dump','$monitor_ids',$monitor_ids) if $b_log;
	eval $end if $b_log;
}

# If we didn't get explicit tool for wayland data, check to see if we got most 
# of the data from /sys/class/drm edid and then skip xrandr to avoid gunking up 
# the data, in that case, all we get from xrandr would be the position, which is
# nice but not a must-have. We've already cleared out all disabled ports.
sub check_wayland_data {
	eval $start if $b_log;
	my ($b_skip_pos,$b_invalid);
	foreach my $key (keys %$monitor_ids){
		# we need these 4 items to construct the grid rectangle
		if (!defined $monitor_ids->{$key}{'pos-x'} ||
		!defined $monitor_ids->{$key}{'pos-y'} ||
		!$monitor_ids->{$key}{'res-x'} ||	!$monitor_ids->{$key}{'res-y'}){
			$b_skip_pos = 1;
		}
		if (!$monitor_ids->{$key}{'res-x'} || !$monitor_ids->{$key}{'res-y'}){
			$b_invalid = 1;
		}
	}
	# ok, we have enough, we don't need to do fallback xrandr checks
	$b_wayland_data = 1 if !$b_invalid;
	eval $end if $b_log;
	return $b_skip_pos;
}

# Set Display rect size for > 1 monitors, monitor positions, size-i, diag
sub wayland_data_advanced {
	eval $start if $b_log;
	my ($b_skip_pos) = @_;
	my (%x_pos,%y_pos);
	my ($x_max,$y_max) = (0,0);
	my @keys = keys %$monitor_ids;
	foreach my $key (@keys){
		if (!$b_skip_pos){
			if ($monitor_ids->{$key}{'res-x'} && $monitor_ids->{$key}{'res-x'} > $x_max){
				$x_max = $monitor_ids->{$key}{'res-x'};
			}
			if ($monitor_ids->{$key}{'res-y'} && $monitor_ids->{$key}{'res-y'} > $y_max){
				$y_max = $monitor_ids->{$key}{'res-y'};
			}
			# Now we'll add the detected x, y res to the trackers
			if (!defined $x_pos{$monitor_ids->{$key}{'pos-x'}}){
				$x_pos{$monitor_ids->{$key}{'pos-x'}} = $monitor_ids->{$key}{'res-x'};
			}
			if (!defined $y_pos{$monitor_ids->{$key}{'pos-y'}}){
				$y_pos{$monitor_ids->{$key}{'pos-y'}} += $monitor_ids->{$key}{'res-y'};
			}
		}
		# this means we failed to get EDID real data, and are using just the wayland 
		# tool to get this info, eg. with BSD without compositor data.
		if ($monitor_ids->{$key}{'size-x'} && $monitor_ids->{$key}{'size-y'} &&
		(!$monitor_ids->{$key}{'size-x-i'} || !$monitor_ids->{$key}{'size-y-i'} ||
		!$monitor_ids->{$key}{'dpi'} || !$monitor_ids->{$key}{'diagonal'})){
			my $size_x = $monitor_ids->{$key}{'size-x'};
			my $size_y = $monitor_ids->{$key}{'size-y'};
			$monitor_ids->{$key}{'size-x-i'} = sprintf("%.2f", ($size_x/25.4)) + 0;
			$monitor_ids->{$key}{'size-y-i'} = sprintf("%.2f", ($size_y/25.4)) + 0;
			$monitor_ids->{$key}{'diagonal'} = sprintf("%.2f", (sqrt($size_x**2 + $size_y**2)/25.4)) + 0;
			$monitor_ids->{$key}{'diagonal-m'} = sprintf("%.0f", (sqrt($size_x**2 + $size_y**2)));
			if ($monitor_ids->{$key}{'res-x'}){
				my $res_x = $monitor_ids->{$key}{'res-x'};
				$monitor_ids->{$key}{'dpi'} = sprintf("%.0f", $res_x * 25.4 / $size_x);
			}
		}
	}
	if (!$b_skip_pos){
		if (scalar @keys > 1 && %x_pos && %y_pos){
			my ($x,$y) = (0,0);
			foreach (keys %x_pos){$x += $x_pos{$_}}
			foreach (keys %y_pos){$y += $y_pos{$_}}
			# handle cases with one tall portrait mode > 2 short landscapes, etc.
			$x = $x_max if $x_max > $x;
			$y = $y_max if $y_max > $y;
			$graphics{'display-rect'} = $x . 'x' . $y;
		}
		my $layouts = [];
		set_monitor_layouts($layouts);
		# only update position, we already have all the rest of the data
		advanced_monitor_data($monitor_ids,$layouts);
		undef $layouts;
	}
	eval $end if $b_log;
}

## WAYLAND COMPOSITOR DATA TOOLS ##
# NOTE: These patterns are VERY fragile, and depend on no changes at all to 
# the data structure, and more important, the order. Something I would put 
# almost no money on being able to count on.
sub wlinfo_data {
	eval $start if $b_log;
	my ($program) = @_;
	my ($data,%mon,@temp,$ref);
	my ($b_iwlo,$b_izxdg,$file,$hz,$id,$pos_x,$pos_y,$res_x,$res_y,$scale);
	if (!$fake{'wl-info'}){
		undef $monitor_ids;
		$data = main::grabber("$program 2>/dev/null",'','strip','ref');
	}
	else {
		$file = "$fake_data_dir/graphics/wayland/weston-info-2-mon-1.txt";
		$file = "$fake_data_dir/graphics/wayland/wayland-info-weston-vm-sparky.txt";
		$data = main::reader($file,'strip','ref');
	}
	print 'wayland/weston-info raw: ', Data::Dumper::Dumper $data if $dbg[46]; 
	main::log_data('dump','@$data', $data) if $b_log;
	foreach (@$data){
		# print 'l: ', $_,"\n";
		if (/^interface: 'wl_output', version: \d+, name: (\d+)$/){
			$b_iwlo = 1;
			$id = $1;
		}
		elsif (/^interface: 'zxdg_output/){
			$b_izxdg = 1;
			$b_iwlo = 0;
		}
		if ($b_iwlo){
			if (/^x: (\d+), y: (\d+), scale: ([\d\.]+)/){
				$mon{$id}->{'pos-x'} = $1;
				$mon{$id}->{'pos-y'} = $2;
				$mon{$id}->{'scale'} = $3;
			}
			elsif (/^physical_width: (\d+) mm, physical_height: (\d+) mm/){
				$mon{$id}->{'size-x'} = $1 if $1; # can be 0 if edid data n/a
				$mon{$id}->{'size-y'} = $2 if $2; # can be 0 if edid data n/a
			}
			elsif (/^make: '([^']+)', model: '([^']+)'/){
				my $make = main::clean($1);
				my $model = main::clean($2);
				$mon{$id}->{'model'} = $make;
				if ($make && $model){
					$mon{$id}->{'model'} = $make . ' ' . $model;
				}
				elsif ($model) {
					$mon{$id}->{'model'} = $model;
				}
				elsif ($make) {
					$mon{$id}->{'model'} = $make;
				}
				# includes remove duplicates and remove unset
				if ($mon{$id}->{'model'}){
					$mon{$id}->{'model'} = main::clean_dmi($mon{$id}->{'model'});
				}
			}
			elsif (/^width: (\d+) px, height: (\d+) px, refresh: ([\d\.]+) Hz,/){
				$mon{$id}->{'res-x'} = $1;
				$mon{$id}->{'res-y'} = $2;
				$mon{$id}->{'hz'} = sprintf('%.0f',$3);
			}
		}
		# note: we don't want to use the 'description' field because that doesn't
		# always contain make/model data, sometimes it's: Built-in/Unknown Display
		elsif ($b_izxdg){
			if (/^output: (\d+)/){
				$id = $1;
			}
			elsif (/^name: '([^']+)'$/){
				$mon{$id}->{'monitor'} = $1;
			}
			elsif (/^logical_x: (\d+), logical_y: (\d+)/){
				$mon{$id}->{'log-pos-x'} = $1;
				$mon{$id}->{'log-pos-y'} = $2;
			}
			elsif (/^logical_width: (\d+), logical_height: (\d+)/){
				$mon{$id}->{'log-x'} = $1;
				$mon{$id}->{'log-y'} = $2;
			}
		}
		if ($b_izxdg && /^interface: '(?!zxdg_output)/){
			last;
		}
	}
	# now we need to map %mon back to $monitor_ids
	if (%mon){
		$b_wayland_data = 1;
		foreach my $key (keys %mon){
			next if !$mon{$key}->{'monitor'}; # no way to know what it is, sorry
			$id = $mon{$key}->{'monitor'};
			$monitor_ids->{$id}{'monitor'} = $id;
 			$monitor_ids->{$id}{'log-x'} = $mon{$key}->{'log-x'} if defined $mon{$key}->{'log-x'};
			$monitor_ids->{$id}{'log-y'} = $mon{$key}->{'log-y'} if defined $mon{$key}->{'log-y'};
			$monitor_ids->{$id}{'pos-x'} = $mon{$key}->{'pos-x'} if defined $mon{$key}->{'pos-x'};
			$monitor_ids->{$id}{'pos-y'} = $mon{$key}->{'pos-y'} if defined $mon{$key}->{'pos-y'};
			$monitor_ids->{$id}{'res-x'} = $mon{$key}->{'res-x'} if defined $mon{$key}->{'res-x'};
			$monitor_ids->{$id}{'res-y'} = $mon{$key}->{'res-y'} if defined $mon{$key}->{'res-y'};
			$monitor_ids->{$id}{'size-x'} = $mon{$key}->{'size-x'} if defined $mon{$key}->{'size-x'};
			$monitor_ids->{$id}{'size-y'} = $mon{$key}->{'size-y'} if defined $mon{$key}->{'size-y'};
			$monitor_ids->{$id}{'hz'} = $mon{$key}->{'hz'} if defined $mon{$key}->{'hz'};
			if (defined $mon{$key}->{'model'} && !$monitor_ids->{$id}{'model'}){
				$monitor_ids->{$id}{'model'} = $mon{$key}->{'model'};
			}
			$monitor_ids->{$id}{'scale'} = $mon{$key}->{'scale'} if defined $mon{$key}->{'scale'};
			# fallbacks in case wl_output block is not present, which happens
			if (!defined $mon{$key}->{'pos-x'} && defined $mon{$key}->{'log-pos-x'}){
				$monitor_ids->{$id}{'pos-x'} = $mon{$key}->{'log-pos-x'};
			}
			if (!defined $mon{$key}->{'pos-y'} && defined $mon{$key}->{'log-pos-y'}){
				$monitor_ids->{$id}{'pos-y'} = $mon{$key}->{'log-pos-y'};
			}
			if (!defined $mon{$key}->{'res-x'} && defined $mon{$key}->{'log-x'}){
				$monitor_ids->{$id}{'res-x'} = $mon{$key}->{'log-x'};
			}
			if (!defined $mon{$key}->{'res-y'} && defined $mon{$key}->{'log-y'}){
				$monitor_ids->{$id}{'res-y'} = $mon{$key}->{'log-y'};
			}
		}
	}
	print '%mon: ', Data::Dumper::Dumper \%mon if $dbg[46]; 
	main::log_data('dump','%mon', \%mon) if $b_log;
	print 'wayland/weston-info: monitor_ids: ', Data::Dumper::Dumper $monitor_ids if $dbg[46];
	eval $end if $b_log;
}

# Note; since not all systems will have /sys data, we'll repack it if it's 
# missing here.
sub swaymsg_data {
	eval $start if $b_log;
	my ($program) = @_;
	my (@data,%json,@temp,$ref);
	my ($b_json,$file,$hz,$id,$model,$pos_x,$pos_y,$res_x,$res_y,$scale,$serial);
	if (!$fake{'swaymsg'}){
		main::load_json() if !$loaded{'json'};
		if ($use{'json'}){
			my $result = qx($program -t get_outputs -r 2>/dev/null);
			# returns array of monitors found
			@data = &{$use{'json'}->{'decode'}}($result) if $result;
			$b_json = 1;
			print "$use{'json'}->{'type'}: " if $dbg[46];
			# print "using: $use{'json'}->{'type'}\n";
		}
		else {
			@data = main::grabber("$program -t get_outputs -p 2>/dev/null",'','strip');
		}
	}
	else {
		undef $monitor_ids;
		$file = "$fake_data_dir/graphics/wayland/swaymsg-2-monitor-1.txt";
		@data = main::reader($file,'strip');
	}
	print 'swaymsg: ', Data::Dumper::Dumper \@data if $dbg[46]; 
	main::log_data('dump','@data', \@data) if $b_log;
	# print Data::Dumper::Dumper \@data;
	if ($b_json){
		$b_wayland_data = 1 if scalar @data > 0;
		foreach my $display (@data){
			foreach my $mon (@$display){
				($hz,$pos_x,$pos_y,$res_x,$res_y,$scale) = ();
				$id = $mon->{'name'};
				if (!$monitor_ids->{$id}{'monitor'}){
					$monitor_ids->{$id}{'monitor'} = $mon->{'name'};
				}
				# we don't want to overwrite good edid model data if we already got it
				if (!$monitor_ids->{$id}{'model'} && $mon->{'make'}){
					$monitor_ids->{$id}{'model'} = main::clean($mon->{'make'});
					if ($mon->{'model'}){
						$monitor_ids->{$id}{'model'} .= ' ' . main::clean($mon->{'model'});
					}
					$monitor_ids->{$id}{'model'} = main::remove_duplicates($monitor_ids->{$id}{'model'});
				}
				if ($monitor_ids->{$id}{'primary'}){
					if ($monitor_ids->{$id}{'primary'} ne 'false'){
						$monitor_ids->{$id}{'primary'} = $id;
						$b_primary = 1;
					}
					else {
						$monitor_ids->{$id}{'primary'} = undef;
					}
				}
				if (!$monitor_ids->{$id}{'serial'}){
					$monitor_ids->{$id}{'serial'} = main::clean_dmi($mon->{'serial'});
				}
				# sys data will only have edid type info, not active state res/pos/hz
				if ($mon->{'current_mode'}){
					if ($hz = $mon->{'current_mode'}{'refresh'}){
						$hz = sprintf('%.0f',($mon->{'current_mode'}{'refresh'}/1000));
						$monitor_ids->{$id}{'hz'} = $hz;
					}
					$monitor_ids->{$id}{'res-x'} = $mon->{'current_mode'}{'width'};
					$monitor_ids->{$id}{'res-y'} = $mon->{'current_mode'}{'height'};
				}
				if ($mon->{'rect'}){
					$monitor_ids->{$id}{'pos-x'} = $mon->{'rect'}{'x'};
					$monitor_ids->{$id}{'pos-y'} = $mon->{'rect'}{'y'};
				}
				if ($mon->{'scale'}){
					$monitor_ids->{$id}{'scale'} =$mon->{'scale'};
				}
			}
		}
	}
	else {
		foreach (@data){
			push(@temp,'~~') if /^Output/i;
			push(@temp,$_);
		}
		push(@temp,'~~') if @temp;
		@data = @temp;
		$b_wayland_data = 1 if scalar @data > 8;
		foreach (@data){
			if ($_ eq '~~' && $id){
				$monitor_ids->{$id}{'hz'} = $hz;
				$monitor_ids->{$id}{'model'} = $model if $model;
				$monitor_ids->{$id}{'monitor'} = $id;
				$monitor_ids->{$id}{'pos-x'} = $pos_x;
				$monitor_ids->{$id}{'pos-y'} = $pos_y;
				$monitor_ids->{$id}{'res-x'} = $res_x;
				$monitor_ids->{$id}{'res-y'} = $res_y;
				$monitor_ids->{$id}{'scale'} = $scale;
				$monitor_ids->{$id}{'serial'} = $serial if $serial;
				($hz,$model,$pos_x,$pos_y,$res_x,$res_y,$scale,$serial) = ();
				$b_wayland_data = 1;
			}
			# Output VGA-1 '<Unknown> <Unknown> ' (focused)
			# unknown how 'primary' is shown, if it shows in this output
			if (/^Output (\S+) '([^']+)'/i){
				$id = $1;
				if ($2 && !$monitor_ids->{$id}{'model'}){
					($model,$serial) = get_model_serial($2);
				}
			}
			elsif (/^Current mode:\s+(\d+)x(\d+)\s+\@\s+([\d\.]+)\s+Hz/i){
				$res_x = $1;
				$res_y = $2;
				$hz = (sprintf('%.0f',($3/1000)) + 0) if $3;
			}
			elsif (/^Position:\s+(\d+),(\d+)/i){
				$pos_x = $1;
				$pos_y = $2;
			}
			elsif (/^Scale factor:\s+([\d\.]+)/i){
				$scale = $1 + 0;
			}
		}
	}
	print 'swaymsg: ', Data::Dumper::Dumper $monitor_ids if $dbg[46];
	eval $end if $b_log;
}

# Like a basic stripped down swaymsg -t get_outputs -p, less data though
# This is EXTREMELY LIKELY TO FAIL! Any tiny syntax change will break this.
sub wlrrandr_data {
	eval $start if $b_log;
	my ($program) = @_;
	my ($file,$hz,$id,$info,$model,$pos_x,$pos_y,$res_x,$res_y,$scale,$serial);
	my ($data,@temp);
	if (!$fake{'wlr-randr'}){
		$data = main::grabber("$program 2>/dev/null",'','strip','ref');
	}
	else {
		undef $monitor_ids;
		$file = "$fake_data_dir/graphics/wayland/wlr-randr-2-monitor-1.txt";
		$data = main::reader($file,'strip','ref');
	}
	foreach (@$data){
		push(@temp,'~~') if /^([A-Z]+-[ABID\d-]+)\s['"]/i;
		push(@temp,$_);
	}
	push(@temp,'~~') if @temp;
	@$data = @temp;
	$b_wayland_data = 1 if scalar @$data > 4;
	print 'wlr-randr: ', Data::Dumper::Dumper $data if $dbg[46]; 
	main::log_data('dump','@$data', $data) if $b_log;
	foreach (@$data){
		if ($_ eq '~~' && $id){
			$monitor_ids->{$id}{'hz'} = $hz;
			$monitor_ids->{$id}{'model'} = $model if $model && !$monitor_ids->{$id}{'model'};
			$monitor_ids->{$id}{'monitor'} = $id;
			$monitor_ids->{$id}{'pos-x'} = $pos_x;
			$monitor_ids->{$id}{'pos-y'} = $pos_y;
			$monitor_ids->{$id}{'res-x'} = $res_x;
			$monitor_ids->{$id}{'res-y'} = $res_y;
			$monitor_ids->{$id}{'scale'} = $scale;
			$monitor_ids->{$id}{'serial'} = $serial if $serial && !$monitor_ids->{$id}{'serial'};
			($hz,$info,$model,$pos_x,$pos_y,$res_x,$res_y,$scale,$serial) = ();
			$b_wayland_data = 1;
		}
		# Output: VGA-1 '<Unknown> <Unknown> ' (focused)
		# DVI-I-1 'Samsung Electric Company SyncMaster H9NX843762' (focused)
		# unknown how 'primary' is shown, if it shows in this output
		if (/^([A-Z]+-[ABID\d-]+)\s([']([^']+)['])?/i){
			$id = $1;
			# if model is set, we got edid data
			if ($3 && !$monitor_ids->{$id}{'model'}){
				($model,$serial) = get_model_serial($3);
			}
		}
		elsif (/^(\d+)x(\d+)\s+px,\s+([\d\.]+)\s+Hz \([^\)]*?current\)/i){
			$res_x = $1;
			$res_y = $2;
			$hz = sprintf('%.0f',$3) if $3;
		}
		elsif (/^Position:\s+(\d+),(\d+)/i){
			$pos_x = $1;
			$pos_y = $2;
		}
		elsif (/^Scale:\s+([\d\.]+)/i){
			$scale = $1 + 0;
		}
	}
	print 'wlr-randr: ', Data::Dumper::Dumper $monitor_ids if $dbg[46];
	eval $end if $b_log;
}

# Return model/serial for those horrible string type values we have to process
# in swaymsg -t get_outputs -p and wlr-randr default output
sub get_model_serial {
	eval $start if $b_log;
	my $info = $_[0];
	my ($model,$serial);
	$info = main::clean($info);
	return if !$info;
	my @parts = split(/\s+/, $info);
	# Perl Madness, lol: the last just checks how many integers in string
	if (scalar @parts > 1 && (length($parts[-1]) > 7) && 
	(($parts[-1] =~ tr/[0-9]//) > 4)){
		$serial = pop @parts;
		$serial = main::clean_dmi($serial); # clears out 0x00000 type non data
	}
	# we're assuming that we'll never get a serial without make/model data too.
	$model = join(' ',@parts) if @parts;
	$model = main::remove_duplicates($model) if $model && scalar @parts > 1;
	eval $end if $b_log;
	return ($model,$serial);
}

# DISPLAY DATA X.org ##
sub display_data_x {
	eval $start if $b_log;
	my ($prog_xdpyinfo,$prog_xdriinfo,$prog_xrandr);
	if ($prog_xdpyinfo = main::check_program('xdpyinfo')){
		xdpyinfo_data($prog_xdpyinfo);
	}
	# print Data::Dumper::Dumper $graphics{'screens'};
	if ($prog_xrandr = main::check_program('xrandr')){
		xrandr_data($prog_xrandr);
	}
	# if tool not installed, falls back to testing Xorg log file
	if ($prog_xdriinfo = main::check_program('xdriinfo')){
		xdriinfo_data($prog_xdriinfo);
	}
	if (!$graphics{'screens'}){
		$graphics{'tty'} = tty_data();
	}
	if (!$prog_xrandr){
		$graphics{'no-monitors'} = main::message('tool-missing-basic','xrandr');
		if (!$prog_xdpyinfo){
			if ($graphics{'protocol'} eq 'wayland'){
				$graphics{'no-screens'} = main::message('screen-wayland');
			}
			else {
				$graphics{'no-screens'} = main::message('tool-missing-basic','xdpyinfo/xrandr');
			}
		}
	}
	print 'Final display x: ', Data::Dumper::Dumper $graphics{'screens'} if $dbg[17];
	main::log_data('dump','$graphics{screens}',$graphics{'screens'}) if $b_log;
	eval $end if $b_log;
}

sub xdriinfo_data {
	eval $start if $b_log;
	my $program = $_[0];
	my (%dri_drivers,$screen,$xdriinfo);
	if (!$fake{'xdriinfo'}){
		$xdriinfo = main::grabber("$program $display_opt 2>/dev/null",'','strip','ref');
	}
	else {
		# $xdriinfo = main::reader("$fake_data_dir/xrandr/xrandr-test-1.txt",'strip','ref');
	}
	foreach $screen (@$xdriinfo){
		if ($screen =~ /^Screen (\d+):\s+(\S+)/){
			$dri_drivers{$1} = $2 if $2 !~ /^not\b/;
		}
	}
	if ($graphics{'screens'}){
		# assign to the screen if it's found
		foreach $screen (@{$graphics{'screens'}}){
			if (defined $dri_drivers{$screen->{'screen'}} ){
				$screen->{'dri-driver'} = $dri_drivers{$screen->{'screen'}};
			}
		}
	}
	# now the display drivers
	foreach $screen (sort keys %dri_drivers){
		if (!$graphics{'dri-drivers'} || 
		!(grep {$dri_drivers{$screen} eq $_} @{$graphics{'dri-drivers'}})){
			push (@{$graphics{'dri-drivers'}},$dri_drivers{$screen});
		}
	}
	print 'x dri driver: ', Data::Dumper::Dumper \%dri_drivers if $dbg[17];
	main::log_data('dump','%dri_drivers',\%dri_drivers) if $b_log;
	eval $end if $b_log;
}

sub xdpyinfo_data {
	eval $start if $b_log;
	my ($program) = @_;
	my ($diagonal,$diagonal_m,$dpi) = ('','','');
	my ($screen_id,$xdpyinfo,@working);
	my ($res_x,$res_y,$size_x,$size_x_i,$size_y,$size_y_i);
	if (!$fake{'xdpyinfo'}){
		$xdpyinfo = main::grabber("$program $display_opt 2>/dev/null","\n",'strip','ref');
	}
	else {
		# my $file;
		# $file = "$fake_data_dir/xdpyinfo/xdpyinfo-1-screen-2-in-inxi.txt";
		# $xdpyinfo = main::reader($file,'strip','ref');
	}
	# @$xdpyinfo = map {s/^\s+//;$_} @$xdpyinfo if @$xdpyinfo;
	# print join("\n",@$xdpyinfo), "\n";
	# X vendor and version detection.
	# new method added since radeon and X.org and the disappearance of 
	# <X server name> version : ...etc. Later on, the normal textual version string 
	# returned, e.g. like: X.Org version: 6.8.2 
	# A failover mechanism is in place: if $version empty, release number parsed instead
	foreach (@$xdpyinfo){
		@working = split(/:\s+/, $_);
		next if (($graphics{'screens'} && $working[0] !~ /^(dimensions$|screen\s#)/) || !$working[0]);
		# print "$_\n";
		if ($working[0] eq 'vendor string'){
			$working[1] =~ s/The\s|\sFoundation//g;
			# some distros, like fedora, report themselves as the xorg vendor, 
			# so quick check here to make sure the vendor string includes Xorg in string
			if ($working[1] !~ /x/i){
				$working[1] .= ' X.org';
			}
			$graphics{'x-server'} = [[$working[1]]];
		}
		elsif ($working[0] eq 'name of display'){
			$graphics{'display-id'} = $working[1];
		}
		# this is the x protocol version
		elsif ($working[0] eq 'version number'){
			$graphics{'x-protocol-version'} = $working[1];
		}
		# not used, but might be good for something?
		elsif ($working[0] eq 'vendor release number'){
			$graphics{'x-vendor-release'} = $working[1];
		}
		# the real X.org version string 
		elsif ($working[0] eq 'X.Org version'){
			push(@{$graphics{'x-server'}->[0]},$working[1]);
		}
		elsif ($working[0] eq 'default screen number'){
			$graphics{'display-default-screen'} = $working[1];
		}
		elsif ($working[0] eq 'number of screens'){
			$graphics{'display-screens'} = $working[1];
		}
		elsif ($working[0] =~ /^screen #([0-9]+):/){
			$screen_id = $1;
		}
		elsif ($working[0] eq 'resolution'){
			$working[1] =~ s/^([0-9]+)x/$1/;
			$graphics{'s-dpi'} = $working[1];
		}
		# This is Screen, not monitor: dimensions: 2560x1024 pixels (677x270 millimeters)
		elsif ($working[0] eq 'dimensions'){
			($dpi,$res_x,$res_y,$size_x,$size_y) = ();
			if ($working[1] =~ /([0-9]+)\s*x\s*([0-9]+)\s+pixels\s+\(([0-9]+)\s*x\s*([0-9]+)\s*millimeters\)/){
				$res_x = $1;
				$res_y = $2;
				$size_x = $3;
				$size_y = $4;
				# flip size x,y if don't roughly  match res x/y ratio
				if ($size_x && $size_y && $res_y){
					flip_size_x_y(\$size_x,\$size_y,\$res_x,\$res_y);
				}
				$size_x_i = ($size_x) ? sprintf("%.2f", ($size_x/25.4)) : 0;
				$size_y_i = ($size_y) ? sprintf("%.2f", ($size_y/25.4)) : 0;
				$dpi = ($res_x && $size_x) ? sprintf("%.0f", ($res_x*25.4/$size_x)) : '';
				$diagonal = ($size_x && $size_y) ? sprintf("%.2f", (sqrt($size_x**2 + $size_y**2)/25.4)) + 0 : '';
				$diagonal_m = ($size_x && $size_y) ? sprintf("%.0f", (sqrt($size_x**2 + $size_y**2))) : '';
			}
			push(@{$graphics{'screens'}}, {
			'diagonal' => $diagonal,
			'diagonal-m' => $diagonal_m,
			'res-x' => $res_x,
			'res-y' => $res_y,
			'screen' => $screen_id,
			's-dpi' => $dpi,
			'size-x' => $size_x,
			'size-x-i' => $size_x_i,
			'size-y' => $size_y,
			'size-y-i' => $size_y_i,
			'source' => 'xdpyinfo',
			});
		}
	}
	print 'Data: xdpyinfo: ', Data::Dumper::Dumper $graphics{'screens'} if $dbg[17];
	main::log_data('dump','$graphics{screens}',$graphics{'screens'}) if $b_log;
	eval $end if $b_log;
}

sub xrandr_data {
	eval $end if $b_log;
	my ($program) = @_;
	my ($diagonal,$diagonal_m,$dpi,$monitor_id,$pos_x,$pos_y,$primary);
	my ($res_x,$res_x_max,$res_y,$res_y_max);
	my ($screen_id,$set_as,$size_x,$size_x_i,$size_y,$size_y_i);
	my (@ids,%monitors,@xrandr,@xrandr_screens);
	if (!$fake{'xrandr'}){
		# @xrandr = main::grabber("$program $display_opt 2>/dev/null",'','strip','arr');
		# note:  --prop support added v 1.2, ~2009 in distros
		@xrandr = qx($program --prop $display_opt 2>&1);
		if ($? > 0){
			# we only want to rerun if unsupported option
			if (grep {/unrecognized/} @xrandr){
				@xrandr = qx($program $display_opt 2>/dev/null);
			}
			else {
				@xrandr = ();
			}
		}
		chomp(@xrandr) if @xrandr;
	}
	else {
		# my $file;
		# $file = "$fake_data_dir/xrandr/xrandr-4-displays-1.txt";
		# $file = "$fake_data_dir/xrandr/xrandr-3-display-primary-issue.txt";
		# $file = "$fake_data_dir/xrandr/xrandr-test-1.txt";
		# $file = "$fake_data_dir/xrandr/xrandr-test-2.txt";
		# $file = "$fake_data_dir/xrandr/xrandr-1-screen-2-in-inxi.txt";
		# @xrandr = main::reader($file,'strip','arr');
	}
	# $graphics{'dimensions'} = (\@dimensions);
	# we get a bit more info from xrandr than xdpyinfo, but xrandr fails to handle
	# multiple screens from different video cards
	# $graphics{'screens'} = undef;
	foreach (@xrandr){
		# note: no mm as with xdpyinfo
		# Screen 0: minimum 320 x 200, current 2560 x 1024, maximum 8192 x 8192
		if (/^Screen ([0-9]+):/){
			$screen_id = $1;
			# handle no xdpyinfo Screen data, multiple xscreens, etc
			if (check_screens($screen_id) && 
			/:\s.*?current\s+(\d+)\s*x\s*(\d+),\smaximum\s+(\d+)\s*x\s*(\d+)/){
				$res_x = $1;
				$res_y = $2;
				$res_x_max = $3;
				$res_y_max = $4;
				push(@{$graphics{'screens'}}, {
				'diagonal' => undef,
				'diagonal-m' => undef,
				'res-x' => $res_x,
				'res-y' => $res_y,
				'screen' => $screen_id,
				's-dpi' => undef,
				'size-x' => undef,
				'size-x-i' => undef,
				'size-y' => undef,
				'size-y-i' => undef,
				'source' => 'xrandr',
				});
			}
			if (%monitors){
				push(@xrandr_screens,{%monitors});
				%monitors = ();
			}
		}
		# HDMI-2 connected 1920x1200+1080+0 (normal left inverted right x axis y axis) 519mm x 324mm
		# DP-1 connected primary 2560x1440+1080+1200 (normal left inverted right x axis y axis) 598mm x 336mm
		# HDMI-1 connected 1080x1920+0+0 left (normal left inverted right x axis y axis) 160mm x 90mm
		# disabled but connected: VGA-1 connected (normal left inverted right x axis y axis)
		elsif (/^([\S]+)\s+connected\s(primary\s)?/){
			$monitor_id = $1;
			$set_as = $2;
			if (/^[^\s]+\s+connected\s(primary\s)?([0-9]+)\s*x\s*([0-9]+)\+([0-9]+)\+([0-9]+)(\s[^(]*\([^)]+\))?(\s([0-9]+)mm\sx\s([0-9]+)mm)?/){
				$res_x = $2;
				$res_y = $3;
				$pos_x = $4;
				$pos_y = $5;
				$size_x = $8;
				$size_y = $9;
				# flip size x,y if don't roughly  match res x/y ratio
				if ($size_x && $size_y && $res_y){
					flip_size_x_y(\$size_x,\$size_y,\$res_x,\$res_y);
				}
				$size_x_i = ($size_x) ? sprintf("%.2f", ($size_x/25.4)) + 0 : 0;
				$size_y_i = ($size_y) ? sprintf("%.2f", ($size_y/25.4)) + 0 : 0;
				$dpi = ($res_x && $size_x) ? sprintf("%.0f", $res_x * 25.4 / $size_x) : '';
				$diagonal = ($res_x && $size_x) ? sprintf("%.2f", (sqrt($size_x**2 + $size_y**2)/25.4)) + 0 : '';
				$diagonal_m = ($res_x && $size_x) ? sprintf("%.0f", (sqrt($size_x**2 + $size_y**2))) : '';
			}
			else {
				($res_x,$res_y,$pos_x,$pos_y,$size_x,$size_x_i,$size_y,$size_y_i,$dpi,$diagonal,$diagonal_m) = ()
			}
			undef $primary;
			push(@ids,[$monitor_id]);
			if ($set_as){
				$primary = $monitor_id;
				$set_as =~ s/\s$//;
				$b_primary = 1;
			}
			$monitors{$monitor_id} = {
			'screen' => $screen_id,
			'monitor' => $monitor_id,
			'pos-x' => $pos_x,
			'pos-y' => $pos_y,
			'primary' => $primary,
			'res-x' => $res_x,
			'res-y' => $res_y,
			'size-x' => $size_x,
			'size-x-i' => $size_x_i,
			'size-y' => $size_y,
			'size-y-i' => $size_y_i,
			'dpi' => $dpi,
			'diagonal' => $diagonal,
			'diagonal-m' => $diagonal_m,
			'position' => $set_as,
			};
			# print "x:$size_x y:$size_y rx:$res_x ry:$res_y dpi:$dpi\n";
			($res_x,$res_y,$size_x,$size_x_i,$size_y,$size_y_i,$set_as) = (0,0,0,0,0,0,0,0,undef);
		}
		elsif (/^([\S]+)\s+disconnected\s/){
			undef $monitor_id;
		}
		elsif ($monitor_id && %monitors) {
			my @working = split(/\s+/,$_);
			# this is the monitor current dimensions
			#  5120x1440     59.98*   29.98  
			# print Data::Dumper::Dumper \@working;
			next if !$working[2];
			if ($working[2] =~ /\*/){
				# print "$working[1] :: $working[2]\n";
				$working[2] =~ s/\*|\+//g;
				$working[2] = sprintf("%.0f",$working[2]);
				$monitors{$monitor_id}->{'hz'} = $working[2];
				($diagonal,$dpi) = ('','');
				# print Data::Dumper::Dumper \@monitors;
			}
			#	\tCONNECTOR_ID: 52
			elsif ($working[1] eq 'CONNECTOR_ID:'){
				# print "$working[1] :: $working[2]\n";
				if (!$monitors{$monitor_id}->{'connector-id'}){
					push(@{$ids[$#ids]},$working[2]);
					$monitors{$monitor_id}->{'connector-id'} = $working[2];
				}
			}
		}
	}
	if (%monitors){
		push(@xrandr_screens,{%monitors});
	}
	my $i = 0;
	my $layouts;
	# corner cases, xrandr screens > xdpyinfo screen, no xdpyinfo counts
	if ($graphics{'screens'} && (!defined $graphics{'display-screens'} || 
	$graphics{'display-screens'} < scalar @{$graphics{'screens'}})){
		$graphics{'display-screens'} = scalar @{$graphics{'screens'}};
	}
	map_monitor_ids(\@ids) if @ids;
	# print "xrandr_screens 1: " . Data::Dumper::Dumper \@xrandr_screens;
	foreach my $main (@{$graphics{'screens'}}){
		# print "h: " . Data::Dumper::Dumper $main;
		# print "h: " . Data::Dumper::Dumper @xrandr_screens;
		# print $main->{'screen'}, "\n";
		foreach my $x_screen (@xrandr_screens){
			# print "d: " . Data::Dumper::Dumper $x_screen;
			my @keys = sort keys %$x_screen;
			if ($x_screen->{$keys[0]}{'screen'} eq $main->{'screen'} && 
				!defined $graphics{'screens'}->[$i]{'monitors'}){
				$graphics{'screens'}->[$i]{'monitors'} = $x_screen;
			}
			if ($extra > 1){
				if (!$layouts){
					$layouts = [];
					set_monitor_layouts($layouts);
				}
				advanced_monitor_data($x_screen,$layouts);
			}
			if (!defined $main->{'size-x'}){
				$graphics{'screens'}->[$i]{'size-missing'} = main::message('tool-missing-basic','xdpyinfo');
			}
		}
		$i++;
	}
	undef $layouts;
	# print "xrandr_screens 2: " . Data::Dumper::Dumper \@xrandr_screens;
	print 'Data: xrandr: ', Data::Dumper::Dumper $graphics{'screens'} if $dbg[17];
	main::log_data('dump','$graphics{screens}',$graphics{'screens'}) if $b_log;
	eval $end if $b_log;
}

# Handle some strange corner cases with more robust testing
sub check_screens {
	my ($id) = @_;
	my $b_use;
	# used: scalar @{$graphics{'screens'}} != (scalar @$xrandr_screens + 1)
	# before but that test can fail in some cases.
	# no screens set in xdpyinfo. If xrandr has > 1 xscreen, this would be false
	if (!$graphics{'screens'}){
		$b_use = 1;
	}
	# verify that any xscreen set so far does not exist in $graphics{'screens'}
	else {
		my $b_detected;
		foreach my $screen (@{$graphics{'screens'}}){
			if ($screen->{'screen'} eq $id){
				$b_detected = 1;
				last;
			}
		}
		$b_use = 1 if !$b_detected;
	}
	return $b_use;
}

# Case where no xpdyinfo display server/version data exists, or to set Wayland
# Xwayland version, or Xvesa data.
sub display_server_data {
	eval $start if $b_log;
	my ($program);
	# load the extra X paths, it's important that these are first, because
	# later Xorg versions show error if run in console or ssh if the true path 
	# is not used.
	@paths = (qw(/usr/lib /usr/lib/xorg /usr/lib/xorg-server /usr/libexec), @paths);
	my (@data,$server,$version);
	if (!$graphics{'x-server'} || !$graphics{'x-server'}->[0][1]){
		# IMPORTANT: both commands send version data to stderr!
		if ($program = main::check_program('Xorg')){
			@data = main::grabber("$program -version 2>&1",'','strip');
			$server = 'X.org';
		}
		elsif ($program = main::check_program('X')){
			@data = main::grabber("$program -version 2>&1",'','strip');
			$server = 'X.org';
		}
		else {
			tinyx_data(\$server,\$version);
		}
		# print join('^ ', @paths), " :: $program\n";
		# print Data::Dumper::Dumper \@data;
		if ($data[0]){
			if ($data[0] =~ /X.org X server (\S+)/i){
				$version =  $1;
			}
			elsif ($data[0] =~ /XFree86 Version (\S+)/i){
				$version = $1;
				$server = 'XFree86';
			}
			elsif ($data[0] =~ /X Window System Version (\S+)/i){
				$version = $1;
			}
		}
		$graphics{'x-server'} = [[$server,$version]] if $server;
	}
	if ($program = main::check_program('Xwayland')){
		undef $version;
		@data = main::grabber("$program -version 2>&1",'','strip');
		# Slackware Linux Project Xwayland Version 21.1.4 (12101004)
		# The X.Org Foundation Xwayland Version 21.1.4 (12101004)
		if (@data){
			$data[0] =~ /Xwayland Version (\S+)/;
			$version = $1;
		}
		$graphics{'x-server'} = [] if !$graphics{'x-server'};
		push(@{$graphics{'x-server'}},['Xwayland',$version]);
	}
	# remove extra X paths from global @paths
	@paths = grep { !/^\/usr\/lib|xorg|libexec/ } @paths;
	eval $end if $b_log;
}

# args: 0: $server; 1: $version - both by ref
sub tinyx_data {
	eval $start if $b_log;
	my ($server,$version) = @_;
	# ordered by likelihood, Xmodesetting proposted by tinycore. Others were 
	# supported by DSL. Existed: Xigs Xipaq Xneomagic Xmga
	my $tinies = 'vesa|fbdev|modesetting|chips|i810|igs|ipaq|mach64|mga|';
	$tinies .= 'neomagic|savage|sis530|trident|trio|ts300';
	# these run as a process, and sometimes also have screen resolution 
	if (my @result = (grep {/^(|\/\S+\/)X($tinies)\b/i} @ps_cmd)){
		if ($result[0] =~ /^(|\/\S+\/)X($tinies)\b/i){
			my $driver = $2;
			my $vsize;
			if ($result[0] =~ /\s-screen\s+(\d+(x\d+)+)\s/){
				$vsize = $1;
			}
			my $tinyx = $graphics{'tinyx'} = 'X' . $driver;
			$$server = "TinyX $tinyx";
			$graphics{'display-driver'} = [$driver];
			# not all tinyx had -version, DSL did not.
			if (my $program = main::check_program($tinyx)){
				$graphics{'xvesa'} = $program if $driver eq 'vesa';
				my @data = main::grabber("$program -version 2>&1",'','strip');
				if (@data && $data[0] =~ /$tinyx from tinyx (\S+)/i){
					$$version = $1;
				}
			}
			# should never happen but just in case
			if (!$graphics{'screens'}){
				# no-screens will store either res or tinyx res missing message
				if ($vsize){
					$graphics{'no-screens'} = $vsize;
				}
				else {
					if (-d '/sys/devices/platform/'){
						my @size = main::globber('/sys/devices/platform/*/graphics/*/virtual_size');
						if (@size && (my $vsize = main::reader($size[0],'strip',0))){
							$vsize =~ s/,/x/g;
							$graphics{'no-screens'} = $vsize;
						}
					}
					if (!$graphics{'no-screens'}){
						$graphics{'no-screens'} = main::message('screen-tinyx',$driver);
					}
				}
			}
		}
	}
	eval $end if $b_log;
}

sub display_protocol {
	eval $start if $b_log;
	$graphics{'protocol'} = '';
	if ($ENV{'XDG_SESSION_TYPE'}){
		$graphics{'protocol'} = $ENV{'XDG_SESSION_TYPE'};
	}
	if (!$graphics{'protocol'} && $ENV{'WAYLAND_DISPLAY'}){
		$graphics{'protocol'} = $ENV{'WAYLAND_DISPLAY'};
	}
	# can show as wayland-0
	if ($graphics{'protocol'} && $graphics{'protocol'} =~ /wayland/i){
		$graphics{'protocol'} = 'wayland';
	}
	# yes, I've seen this in 2019 distros, sigh
	elsif ($graphics{'protocol'} eq 'tty'){
		$graphics{'protocol'} = '';
	}
	# If no other source, get user session id, then grab session type.
	# loginctl also results in the session id
	# undef $graphics{'protocol'};
	if (!$graphics{'protocol'}){
		if (my $program = main::check_program('loginctl')){
			my $id = '';
			# $id = $ENV{'XDG_SESSION_ID'}; # returns tty session in console
			my @data = main::grabber("$program --no-pager --no-legend 2>/dev/null",'','strip');
			foreach (@data){
				# some systems show empty or ??? for TTY field, but whoami should do ok
				next if /(ttyv?\d|pts\/)/; # freebsd: ttyv3
				# in display, root doesn't show in the logins
				next if $client{'whoami'} && $client{'whoami'} ne 'root' && !/\b$client{'whoami'}\b/;
				$id = (split(/\s+/, $_))[0];
				# multiuser? too bad, we'll go for the first one that isn't a tty/pts
				last; 
			}
			if ($id){
				my $temp = (main::grabber("$program show-session $id -p Type --no-pager --no-legend 2>/dev/null"))[0];
				$temp =~ s/Type=// if $temp;
				# ssh will not show /dev/ttyx so would have passed the first test
				$graphics{'protocol'} = $temp if $temp && $temp ne 'tty';
			}
		}
	}
	$graphics{'protocol'} = lc($graphics{'protocol'}) if $graphics{'protocol'};
	eval $end if $b_log;
}

## DRIVER DATA ##
# for wayland display/monitor drivers, or if no display drivers found for x
sub gpu_drivers_sys {
	eval $start if $b_log;
	my ($id) = @_;
	my ($driver);
	my $drivers = [];
	# we only want list of drivers for cards with a connected monitor, and inactive
	# ports are already removed by the 'all' stage.
	foreach my $port (keys %{$monitor_ids}){
		if (!$monitor_ids->{$port}{'drivers'} ||
		($id ne 'all' && $id ne $port) ||
		!$monitor_ids->{$port}{'status'} || 
		$monitor_ids->{$port}{'status'} ne 'connected'){
			next;
		}
		else {
			foreach $driver (@{$monitor_ids->{$port}{'drivers'}}){
				push(@$drivers,$driver);
			}
		}
	}
	if (@$drivers){
		@$drivers = sort(@$drivers);
		main::uniq($drivers);
	}
	eval $end if $b_log;
	return $drivers;
}

sub display_drivers_x {
	eval $start if $b_log;
	my $driver_data = [];
	# print 'x-log: ' . $system_files{'xorg-log'} . "\n";
	if (my $log = $system_files{'xorg-log'}){
		if ($fake{'xorg-log'}){
			# $log = "$ENV{HOME}/bin/scripts/inxi/data/xorg-logs/Xorg.0-voyager-serena.log";
			# $log = "$ENV{HOME}/bin/scripts/inxi/data/xorg-logs/loading-unload-failed-all41-mint.txt";
			# $log = "$ENV{HOME}/bin/scripts/inxi/data/xorg-logs/loading-unload-failed-phd21-mint.txt";
			# $log = "$ENV{HOME}/bin/scripts/inxi/data/xorg-logs/Xorg.0-gm10.log";
			# $log = "$ENV{HOME}/bin/scripts/inxi/data/xorg-logs/xorg-multi-driver-1.log";
		}
		my $x_log = main::reader($log,'','ref');
		# list is from sgfxi plus non-free drivers, plus ARM drivers. 
		# Don't use ati. It's just a wrapper for: r128, mach64, radeon
		my $list = join('|', qw(amdgpu apm ark armsoc atimisc
		chips cirrus cyrix etnaviv fbdev fbturbo fglrx geode glide glint 
		i128 i740 i810-dec100 i810e i810 i815 i830 i845 i855 i865 i915 i945 i965 
		iftv igs imstt intel ipaq ivtv mach64 mesa mga m68k modesetting neomagic 
		newport nouveau nova nsc nvidia nv openchrome r128 radeonhd radeon rendition 
		s3virge s3 savage siliconmotion sisimedia sisusb sis sis530 sunbw2 suncg14 
		suncg3 suncg6 sunffb sunleo suntcx tdfx tga trident trio ts300 tseng 
		unichrome v4l vboxvideo vesa vga via vmware vmwgfx voodoo));
		# $list = qr/$list/i; # qr/../i only added perl 5.14, fails on older perls
		my ($b_use_dri,$dri,$driver,%drivers);
		my ($alternate,$failed,$loaded,$unloaded);
		my $pattern = 'Failed|Unload|Loading';
		# preferred source xdriinfo because it's current and accurate, but fallback here
		if (!$graphics{'dri-drivers'}){
			$b_use_dri = 1;
			$pattern .= '|DRI driver:';
		}
		# $pattern = qr/$pattern/i;  # qr/../i only added perl 5.14, fails on older perls
		# it's much cheaper to grab the simple pattern match then do the expensive one 
		# in the main loop.
		# @$x_log = grep {/Failed|Unload|Loading/} @$x_log;
		foreach my $line (@$x_log){
			next if $line !~ /$pattern/i;
			# print "$line\n";
			# note that in file names, driver is always lower case. Legacy _drv.o
			if ($line =~ /\sLoading.*($list)_drv\.s?o$/i){
				$driver=lc($1);
				# we get all the actually loaded drivers first, we will use this to compare the
				# failed/unloaded, which have not always actually been truly loaded
				$drivers{$driver}='loaded';
			}
			# openbsd uses UnloadModule: 
			elsif ($line =~ /(Unloading\s|UnloadModule).*\"?($list)(_drv\.s?o)?\"?$/i){
				$driver=lc($2);
				# we get all the actually loaded drivers first, we will use this to compare the
				# failed/unloaded, which have not always actually been truly loaded
				if (exists $drivers{$driver} && $drivers{$driver} ne 'alternate'){
					$drivers{$driver}='unloaded';
				}
			}
			# verify that the driver actually started the desktop, even with false failed messages 
			# which can occur. This is the driver that is actually driving the display.
			# note that xorg will often load several modules, like modesetting,fbdev,nouveau
			# NOTE:
			# (II) UnloadModule: "nouveau"
			# (II) Unloading nouveau
			# (II) Failed to load module "nouveau" (already loaded, 0)
			# (II) LoadModule: "modesetting"
			elsif ($line =~ /Failed.*($list)\"?.*$/i){
				# Set driver to lower case because sometimes it will show as 
				# RADEON or NVIDIA in the actual x start
				$driver=lc($1);
				# we need to make sure that the driver has already been truly loaded, 
				# not just discussed
				if (exists $drivers{$driver} && $drivers{$driver} ne 'alternate'){
					if ($line !~  /\(already loaded/){
						$drivers{$driver}='failed';
					}
					# reset the previous line's 'unloaded' to 'loaded' as well
					else {
						$drivers{$driver}='loaded';
					}
				}
				elsif ($line =~ /module does not exist/){
					$drivers{$driver}='alternate';
				}
			}
			elsif ($b_use_dri && $line =~ /DRI driver:\s*(\S+)/i){
				$dri = $1;
				if (!$graphics{'dri-drivers'} || 
				!(grep {$dri eq $_} @{$graphics{'dri-drivers'}})){
					push(@{$graphics{'dri-drivers'}},$dri);
				}
			}
		}
		# print 'drivers: ', Data::Dumper::Dumper \%drivers;
		foreach (sort keys %drivers){
			if ($drivers{$_} eq 'loaded'){
				push(@$loaded,$_);
			}
			elsif ($drivers{$_} eq 'unloaded'){
				push(@$unloaded,$_);
			}
			elsif ($drivers{$_} eq 'failed'){
				push(@$failed,$_);
			}
			elsif ($drivers{$_} eq 'alternate'){
				push(@$alternate,$_);
			}
		}
		if ($loaded || $unloaded || $failed || $alternate){
			$driver_data = [$loaded,$unloaded,$failed,$alternate];
		}
	}
	eval $end if $b_log;
	# print 'source: ', Data::Dumper::Dumper $driver_data;
	return $driver_data;
}

sub set_mesa_drivers {
	%mesa_drivers = (
	'anv' => 'intel',
	'crocus' => 'intel',
	'etnaviv' => 'vivante',
	'freedreno' => 'qualcomm',
	'i915' => 'intel',
	'i965' => 'intel',
	'iris' => 'intel',
	'lima' => 'mali',
	'nouveau' => 'nvidia',
	'nova' => 'nvidia',
	'panfrost' => 'mali/bifrost',
	'r200' => 'amd',
	'r300' => 'amd',
	'r600' => 'amd',
	'radeonsi' => 'amd',
	'radv' => 'amd',
	'svga3d' => 'vmware',
	'v3d' => 'broadcom',
	'v3dv' => 'broadcom',
	'vc4' => 'broadcom',
	);
}

## GPU DATA ##
sub set_amd_data {
	$gpu_amd = [
	# no ids
	{'arch' => 'Wonder',
	'ids' => '',
	'code' => 'Wonder',
	'process' => 'NEC 800nm',
	'years' => '1986-92',
	},
	{'arch' => 'Mach',
	'ids' => '4158|4354|4358|4554|4654|4754|4755|4758|4c42|4c49|4c50|4c54|5354|' .
	'5654|5655|5656',
	'code' => 'Mach64',
	'process' => 'TSMC 500-600nm',
	'years' => '1992-97',
	},
	{'arch' => 'Rage-2',
	'ids' => '4756|4757|4759|475a|4c47',
	'code' => 'Rage-2',
	'process' => 'TSMC 500nm',
	'years' => '1996',
	},
	{'arch' => 'Rage-3',
	'ids' => '4742|4744|4749|474d|474f|4750|4752',
	'code' => 'Rage-3',
	'process' => 'TSMC 350nm',
	'years' => '1997-99',
	},
	{'arch' => 'Rage-4',
	'ids' => '474e|4753|4c46|4c4d|4c4e|4c52|4d46|5044|5046|5050|5052|5245|5246|' .
	'524b|524c|534d|5446|5452',
	'code' => 'Rage-4',
	'process' => 'TSMC 250-350nm',
	'years' => '1998-99',
	},
	# vendor 1014 IBM, subvendor: 1092
	# 0172|0173|0174|0184
	# {'arch' => 'IBM',
	# 'code' => 'Fire GL',
	# 'process' => 'IBM 156-250nm',
	# 'years' => '1999-2001',
	# },
	# rage 5 was game cube flipper chip
# rage 5 was game cube flipper chip 2000
	{'arch' => 'Rage-6',
	'ids' => '4137|4337|4437|4c59|5144|5159|515e',
	'code' => 'R100',
	'process' => 'TSMC 180nm',
	'years' => '2000-07',
	},
	# |Radeon (7[3-9]{2}|8d{3}|9[5-9]d{2}
	{'arch' => 'Rage-7',
	'ids' => '4136|4150|4152|4170|4172|4242|4336|4966|496e|4c57|4c58|4c66|4c6e|' .
	'4e51|4f72|4f73|5148|514c|514d|5157|5834|5835|5940|5941|5944|5960|5961|5962|' .
	'5964|5965|5b63|5b72|5b73|5c61|5c63|5d44|5d45|7100|7101|7102|7109|710a|710b|' .
	'7120|7129|7140|7142|7143|7145|7146|7147|7149|714a|715f|7162|7163|7166|7167|' .
	'7181|7183|7186|7187|718b|718c|718d|7193|7196|719f|71a0|71a1|71a3|71a7|71c0|' .
	'71c1|71c2|71c3|71c5|71c6|71c7|71ce|71d5|71d6|71de|71e0|71e1|71e2|71e6|71e7|' .
	'7240|7244|7248|7249|724b|7269|726b|7280|7288|7291|7293|72a0|72a8|72b1|72b3|' .
	'7834|7835|791e',
	'code' => 'R200',
	'process' => 'TSMC 150nm',
	'years' => '2001-06',
	},
	{'arch' => 'Rage-8',
	'ids' => '4144|4146|4147|4148|4151|4153|4154|4155|4157|4164|4165|4166|4168|' .
	'4171|4173|4e44|4e45|4e46|4e47|4e48|4e49|4e4b|4e50|4e52|4e54|4e64|4e65|4e66|' .
	'4e67|4e68|4e69|4e6a|4e71|5a41|5a42|5a61|5a62',
	'code' => 'R300',
	'process' => 'TSMC 130nm',
	'years' => '2002-07',
	},
	{'arch' => 'Rage-9',
	'ids' => '3150|3151|3152|3154|3155|3171|3e50|3e54|3e70|4e4a|4e56|5460|5461|' .
	'5462|5464|5657|5854|5874|5954|5955|5974|5975|5b60|5b62|5b64|5b65|5b66|5b70|' .
	'5b74|5b75',
	'code' => 'Radeon IGP',
	'process' => 'TSMC 110nm',
	'years' => '2003-08',
	},
	{'arch' => 'R400',
	'ids' => '4a49|4a4a|4a4b|4a4d|4a4e|4a4f|4a50|4a54|4a69|4a6a|4a6b|4a70|4a74|' .
	'4b49|4b4b|4b4c|4b69|4b6b|4b6c|5549|554a|554b|554d|554e|554f|5550|5551|5569|' .
	'556b|556d|556f|5571|564b|564f|5652|5653|5d48|5d49|5d4a|5d4d|5d4e|5d4f|5d50|' .
	'5d52|5d57|5d6d|5d6f|5d72|5d77|5e48|5e49|5e4a|5e4b|5e4c|5e4d|5e4f|5e6b|5e6d|' .
	'5f57|791f|793f|7941|7942|796e',
	'code' => 'R400',
	'process' => 'TSMC 55-130nm',
	'years' => '2004-08',
	},
	{'arch' => 'R500',
	'ids' => '7104|710e|710f|7124|712e|712f|7152|7153|7172|7173|7188|718a|719b|' .
	'71bb|71c4|71d2|71d4|71f2|7210|7211|724e|726e|940f|94c8|94c9|9511|9581|9583|' .
	'958b|958d',
	'code' => 'R500',
	'process' => 'TSMC 90nm',
	'years' => '2005-07',
	},
	# process:  tsmc 55nm, 65nm, xbox 360s at 40nm
	{'arch' => 'TeraScale',
	'ids' => '4346|4630|4631|9400|9401|9403|9405|940a|940b|9440|9441|9442|9443|' .
	'9444|9446|944a|944b|944c|944e|9450|9452|9456|945a|9460|9462|946a|9480|9488|' .
	'9489|9490|9491|9495|9498|949c|949e|949f|94a0|94a1|94a3|94b3|94b4|94c1|94c3|' .
	'94c4|94c5|94c7|94cb|94cc|9500|9501|9504|9505|9506|9507|9508|9509|950f|9513|' .
	'9515|9519|9540|954f|9552|9553|9555|9557|955f|9580|9586|9587|9588|9589|958a|' .
	'958c|9591|9593|9595|9596|9597|9598|9599|95c0|95c2|95c4|95c5|95c6|95c9|95cc|' .
	'95cd|95cf|9610|9611|9612|9613|9614|9615|9616|9710|9712|9713|9714|9715',
	'code' => 'R6xx/RV6xx/RV7xx',
	'process' => 'TSMC 55-65nm',
	'years' => '2005-13',
	},
	{'arch' => 'TeraScale-2',
	'ids' => '6720|6738|6739|673e|6740|6741|6742|6743|6749|674a|6750|6751|6758|' .
	'6759|675b|675d|675f|6760|6761|6763|6764|6765|6766|6767|6768|6770|6771|6772|' .
	'6778|6779|677b|6840|6841|6842|6843|6880|6888|6889|688a|688c|688d|6898|6899|' .
	'689b|689c|689d|689e|68a0|68a1|68a8|68a9|68b8|68b9|68ba|68be|68bf|68c0|68c1|' .
	'68c7|68c8|68c9|68d8|68d9|68da|68de|68e0|68e1|68e4|68e5|68e8|68e9|68f1|68f2|' .
	'68f8|68f9|68fa|68fe|9640|9641|9642|9643|9644|9645|9647|9648|9649|964a|964b|' .
	'964c|964e|964f|9802|9803|9804|9805|9806|9807|9808|9809|980a|9925|9926',
	'code' => 'Evergreen',
	'process' => 'TSMC 32-40nm',
	'years' => '2009-15',
	},
	{'arch' => 'TeraScale-3',
	'ids' => '6704|6707|6718|6719|671c|671d|671f|9900|9901|9903|9904|9905|9906|' .
	'9907|9908|9909|990a|990b|990c|990d|990e|990f|9910|9913|9917|9918|9919|9990|' .
	'9991|9992|9993|9994|9995|9996|9997|9998|9999|999a|999b|999c|999d|99a0|99a2|' .
	'99a4',
	'code' => 'Northern Islands',
	'process' => 'TSMC 32nm',
	'years' => '2010-13',
	},
	{'arch' => 'GCN-1',
	'ids' => '154c|6600|6601|6604|6605|6606|6607|6608|6609|6610|6611|6613|6617|' .
	'6631|6660|6663|6664|6665|6666|6667|666f|6780|6784|6788|678a|6798|6799|679a|' .
	'679b|679e|679f|6800|6801|6802|6806|6808|6809|6810|6811|6816|6817|6818|6819|' .
	'6820|6821|6822|6823|6825|6826|6827|6828|6829|682a|682b|682c|682d|682f|6830|' .
	'6831|6835|6837|683d|683f|684c',
	'code' => 'Southern Islands',
	'process' => 'TSMC 28nm',
	'years' => '2011-20',
	},
	# process: both TSMC and GlobalFoundries
	{'arch' => 'GCN-2',
	'ids' => '1304|1305|1306|1307|1309|130a|130b|130c|130d|130e|130f|1310|1311|' .
	'1312|1313|1315|1316|1317|1318|131b|131c|131d|6640|6641|6646|6647|6649|664d|' .
	'6650|6651|6658|665c|665d|665f|67a0|67a1|67a2|67a8|67a9|67aa|67b0|67b1|67b8|' .
	'67b9|67be|9830|9831|9832|9833|9834|9835|9836|9837|9838|9839|983d|9850|9851|' .
	'9852|9853|9854|9855|9856|9857|9858|9859|985a|985b|985c|985d|985e|985f|991e|' .
	'9920|9922',
	'code' => 'Sea Islands',
	'process' => 'GF/TSMC 16-28nm',
	'years' => '2013-17',
	},
	{'arch' => 'GCN-3',
	'ids' => '6900|6901|6902|6907|6920|6921|6929|692b|692f|6930|6938|6939|693b|' .
	'7300|730f|9874|98c0|98e4',
	'code' => 'Volcanic Islands',
	'process' => 'TSMC 28nm',
	'years' => '2014-19',
	},
	{'arch' => 'GCN-4',
	'ids' => '154e|1551|1552|1561|67c0|67c1|67c2|67c4|67c7|67ca|67cc|67cf|67d0|' .
	'67d4|67d7|67df|67e0|67e1|67e3|67e8|67e9|67eb|67ef|67ff|694c|694e|694f|6980|' .
	'6981|6984|6985|6986|6987|698f|6995|6997|699f|6fdf|9924|9925',
	'code' => 'Arctic Islands',
	'process' => 'GF 14nm',
	'years' => '2016-20',
	},
	{'arch' => 'GCN-5.1',
	'ids' => '15d8|15dd|15df|15e7|1636|1638|164c|66a0|66a1|66a2|66a3|66a7|66af|' .
	'69af',
	'code' => 'Vega-2',
	'process' => 'TSMC n7 (7nm)',
	'years' => '2018-22+',
	},
	{'arch' => 'GCN-5',
	'ids' => '15d8|15d9|15dd|15e7|15ff|1636|1638|164c|66a0|66a1|66a2|66a3|66a4|' .
	'66a7|66af|6860|6861|6862|6863|6864|6867|6868|6869|686a|686b|686c|686d|686e|' .
	'687f|69a0|69a1|69a2|69a3|69af',
	'code' => 'Vega',
	'process' => 'GF 14nm',
	'years' => '2017-20',
	},
	{'arch' => 'RDNA-1',
	'ids' => '13e9|13f9|13fe|1478|1479|1607|7310|7312|7318|7319|731a|731b|731e|' .
	'731f|7340|7341|7343|7347|734f|7360|7362',
	'code' => 'Navi-1x',
	'process' => 'TSMC n7 (7nm)',
	'years' => '2019-20',
	},
	{'arch' => 'RDNA-2',
	'ids' => '1435|1506|163f|164d|164e|1681|73a0|73a1|73a2|73a3|73a5|73ab|73ae|' .
	'73af|73bf|73c0|73c1|73c3|73ce|73df|73e0|73e1|73e3|73ef|73ff|7420|7421|7422|' .
	'7423|7424|743f',
	'code' => 'Navi-2x',
	'process' => 'TSMC n7 (7nm)',
	'years' => '2020-22',
	},
	{'arch' => 'RDNA-3',
	'ids' => '73a8|73c4|73c5|73c8|7448|744c|745e|7460|7461|7470|7478|747e',
	'code' => 'Navi-3x',
	'process' => 'TSMC n5 (5nm)',
	'years' => '2022+',
	},
	{'arch' => 'RDNA-3',
	'ids' => '73f0|7480|7481|7483|7487|7489|748b|749f',
	'code' => 'Navi-33',-
	'process' => 'TSMC n6 (6nm)',
	'years' => '2023+',
	},
	{'arch' => 'RDNA-3',
	'ids' => '15bf|15c8|164f|1900|1901',
	'code' => 'Phoenix',
	'process' => 'TSMC n4 (4nm)',
	'years' => '2023+',
	},
	{'arch' => 'CDNA-1',
	'ids' => '7388|738c|738e',
	'code' => 'Instinct-MI1xx',
	'process' => 'TSMC n7 (7nm)',
	'years' => '2020',
	},
	{'arch' => 'CDNA-2',
	'ids' => '7408|740c|740f',
	'code' => 'Instinct-MI2xx',
	'process' => 'TSMC n6 (6nm)',
	'years' => '2021-22+',
	},
	{'arch' => 'CDNA-3',
	'ids' => '74a0|74a1',
	'code' => 'Instinct-MI3xx',
	'process' => 'TSMC n5 (5nm)',
	'years' => '2023+',
	},
	];
}

sub set_intel_data {
	$gpu_intel = [
	{'arch' => 'Gen-1',
	'ids' => '1132|7120|7121|7122|7123|7124|7125|7126|7128|712a',
	'code' => '',
	'process' => 'Intel 150nm',
	'years' => '1998-2002',
	},
	# ill-fated standalone gfx card
	{'arch' => 'i740',
	'ids' => '7800',
	'code' => '',
	'process' => 'Intel 150nm',
	'years' => '1998',
	},
	{'arch' => 'Gen-2',
	'ids' => '2562|2572|3577|3582|358e',
	'code' => '',
	'process' => 'Intel 130nm',
	'years' => '2002-03',
	},
	{'arch' => 'Gen-3',
	'ids' => '2582|2592|2780|2782|2792',
	'code' => 'Intel 130nm',
	'process' => '',
	'years' => '2004-05',
	},
	{'arch' => 'Gen-3.5',
	'ids' => '2772|2776|27a2|27a6|27ae|2972|2973',
	'code' => '',
	'process' => 'Intel 90nm',
	'years' => '2005-06',
	},
	{'arch' => 'Gen-4',
	'ids' => '2982|2983|2992|2993|29a2|29a3|29b2|29b3|29c2|29c3|29d2|29d3|2a02|' .
	'2a03|2a12|2a13',
	'code' => '',
	'process' => 'Intel 65n',
	'years' => '2006-07',
	},
	{'arch' => 'PowerVR SGX535',
	'ids' => '4100|8108|8109|a001|a002|a011|a012',
	'code' => '',
	'process' => 'Intel 45-130nm',
	'year' => '2008-10',
	},
	{'arch' => 'Gen-5',
	'ids' => '2a41|2a42|2a43|2e02|2e03|2e12|2e13|2e22|2e23|2e32|2e33|2e42|2e43|' .
	'2e92|2e93',
	'code' => '',
	'process' => 'Intel 45nm',
	'years' => '2008',
	},
	{'arch' => 'PowerVR SGX545',
	'ids' => '0be0|0be1|0be2|0be3|0be4|0be5|0be6|0be7|0be8|0be9|0bea|0beb|0bec|' .
	'0bed|0bee|0bef',
	'code' => '',
	'process' => 'Intel 65nm',
	'years' => '2008-10',
	},
	{'arch' => 'Gen-5.75',
	'ids' => '0042|0046|004a|0402|0412|0416',
	'code' => '',
	'process' => 'Intel 45nm',
	'years' => '2010',
	},
	{'arch' => 'Knights',
	'ids' => '',
	'code' => '',
	'process' => 'Intel 22nm',
	'years' => '2012-13',
	},
	{'arch' => 'Gen-6',
	'ids' => '0102|0106|010a|010b|010e|0112|0116|0122|0126|08cf',
	'code' => 'Sandybridge',
	'process' => 'Intel 32nm',
	'years' => '2011',
	},
	{'arch' => 'Gen-7.5',
	'ids' => '0402|0406|040a|040b|040e|0412|0416|041a|041b|041e|0422|0426|042a|' .
	'042b|042e|0a02|0a06|0a0a|0a0b|0a0e|0a12|0a16|0a1a|0a1b|0a1e|0a22|0a26|0a2a|' .
	'0a2b|0a2e|0c02|0c06|0c0a|0c0b|0c0e|0c12|0c16|0c1a|0c1b|0c1e|0c22|0c26|0c2a|' .
	'0c2b|0c2e|0d02|0d06|0d0a|0d0b|0d0e|0d12|0d16|0d1a|0d1b|0d1e|0d22|0d26|0d2a|' .
	'0d2b|0d2e',
	'code' => '',
	'process' => 'Intel 22nm',
	'years' => '2013',
	},
	{'arch' => 'Gen-7',
	'ids' => '0152|0155|0156|0157|015a|015e|0162|0166|016a|0172|0176|0f30|0f31|' .
	'0f32|0f33',
	'code' => '',
	'process' => 'Intel 22nm',
	'years' => '2012-13',
	},
	{'arch' => 'Gen-8',
	'ids' => '1602|1606|160a|160b|160d|160e|1612|1616|161a|161b|161d|161e|1622|' .
	'1626|162a|162b|162d|162e|1632|1636|163a|163b|163d|163e|22b0|22b1|22b2|22b3',
	'code' => '',
	'process' => 'Intel 14nm',
	'years' => '2014-15',
	},
	{'arch' => 'Gen-9.5',
	'ids' => '3184|3185|3e90|3e91|3e92|3e93|3e94|3e96|3e98|3e99|3e9a|3e9b|3e9c|' .
	'3ea0|3ea1|3ea2|3ea3|3ea4|3ea5|3ea6|3ea7|3ea8|3ea9|5902|5906|5908|590a|590b|' .
	'590e|5912|5913|5915|5916|5917|591a|591b|591c|591d|591e|5921|5923|5926|5927|' .
	'593b|87c0|87ca|9b21|9b41|9ba0|9ba2|9ba4|9ba5|9ba8|9baa|9bab|9bac|9bc0|9bc2|' .
	'9bc4|9bc5|9bc6|9bc8|9bca|9bcb|9bcc|9be6|9bf6',
	'code' => '',
	'process' => 'Intel 14nm',
	'years' => '2016-20',
	},
	{'arch' => 'Gen-9',
	'ids' => '0a84|1902|1906|190a|190b|190e|1912|1913|1915|1916|1917|191a|191b|' .
	'191d|191e|1921|1923|1926|1927|192a|192b|192d|1932|193a|193b|193d|1a84|1a85|' .
	'5a84|5a85',
	'code' => '',
	'process' => 'Intel 14n',
	'years' => '2015-16',
	},
	# gen10 was cancelled., 
	{'arch' => 'Gen-11',
	'ids' => '0d16|0d26|0d36|4541|4551|4555|4557|4571|4e51|4e55|4e57|4e61|4e71|' .
	'8a50|8a51|8a52|8a53|8a54|8a56|8a57|8a58|8a59|8a5a|8a5b|8a5c|8a5d|8a70|8a71|' .
	'9840|9841',
	'code' => '',
	'process' => 'Intel 10nm',
	'years' => '2019-21',
	},
	{'arch' => 'Gen-12.1',
	'ids' => '4905|4907|4908|4c80|4c8a|4c8b|4c8c|4c90|4c9a|9a40|9a49|9a59|9a60|' .
	'9a68|9a70|9a78|9ac0|9ac9|9ad9|9af8',
	'code' => '',
	'process' => 'Intel 10nm',
	'years' => '2020-21',
	},
	{'arch' => 'Gen-12.2',
	'ids' => '4626|4628|462a|4636|4638|463a|4682|4688|468a|468b|4690|4692|4693|' .
	'46a3|46a6|46a8|46aa|46b0|46b1|46b3|46b6|46b8|46ba|46c1|46c3|46d0|46d1|46d2|' .
	'46d3|46d4',
	'code' => '',
	'process' => 'Intel 10nm',
	'years' => '2021-22+',
	},
	{'arch' => 'Gen-12.5',
	'ids' => '0bd0|0bd5|0bd6|0bd7|0bd9|0bda|0bdb',
	'code' => '',
	'process' => 'Intel 10nm',
	'years' => '2021-23+',
	},
	# Jupiter Sound cancelled?
	{'arch' => 'Gen-12.7',
	'ids' => '4f80|4f81|4f82|4f83|4f84|4f85|4f86|4f87|4f88|5690|5691|5692|5693|' .
	'5694|5695|5696|5697|5698|56a0|56a1|56a3|56a4|56a5|56a6|56a7|56a8|56a9|56b0|' .
	'56b1|56b2|56b3|56ba|56bb|56bc|56bd|56be|56bf',
	'code' => 'Alchemist',
	'process' => 'TSMC n6 (7nm)',
	'years' => '2022+',
	},
	{'arch' => 'Gen-12.7',
	'ids' => '56c0|56c1',
	'code' => '',
	'process' => 'TSMC n6 (7nm)',
	'years' => '2022+',
	},
	{'arch' => 'Gen-13',
	'ids' => 'a70d|a720|a721|a74d|a780|a781|a782|a783|a788|a789|a78a|a78b|a7a0|' .
	'a7a1|a7a8|a7a9|a7aa|a7ab|a7ac|a7ad',
	'code' => '',
	'process' => 'Intel 7 (10nm)',
	'years' => '2022+',
	},
	{'arch' => 'Gen-13',
	'ids' => '7d40|7d45|7d55|7d60|7dd5',
	'code' => '',
	'process' => 'Intel 4 (7nm+)',
	'years' => '2023+',
	},
	{'arch' => 'Gen-14',
	'ids' => '6420|64a0|64b0',
	'code' => '',
	'process' => 'TSMC 3nm',
	'years' => '2024+',
	},
	{'arch' => 'Gen-15',
	'ids' => '7d41|7d51|7d67|7dd1',
	'code' => '',
	'process' => 'TSMC 3nm?',
	'years' => '2025+',
	},
	];
}

sub set_nv_data {
	# this is vendor id: 12d2, nv1/riva/tnt type cards
	# 0008|0009|0010|0018|0019
	# and these are vendor id: 10de for 73.14
	# 0020|0028|0029|002c|002d|00a0|0100|0101|0103|0150|0151|0152|0153
	# generic fallback if we don't have the actual EOL termination date
	my $date = $self_date;
	$date =~ s/-\d+$//;
	my $status_current = main::message('nv-current',$date);
	# load legacy data, note, if there are 2 or more arch in 1 legacy, it has 1
	# item per arch. kernel/last/xorg support either from nvidia or sgfxi
	## Legacy 71.86.xx
	$gpu_nv = [
	{'arch' => 'Fahrenheit',
	'ids' => '0008|0009|0010|0018|0019|0020|0028|0029|002c|002d|00a0',
	'code' => 'NVx',
	'kernel' => '2.6.38',
	'legacy' => 1,
	'process' => 'TSMC 220-350nm',
	'release' => '71.86.15',
	'series' => '71.86.xx',
	'status' => main::message('nv-legacy-eol','2011-08-xx'),
	'xorg' => '1.7',
	'years' => '1998-2000',
	},
	{'arch' => 'Celsius',
	'ids' => '0100|0101|0103|0150|0151|0152|0153',
	'code' => 'NV1x',
	'kernel' => '2.6.38',
	'legacy' => 1,
	'process' => 'TSMC 150-220nm',
	'release' => '71.86.15',
	'series' => '71.86.xx',
	'status' => main::message('nv-legacy-eol','2011-08-xx'),
	'xorg' => '1.7',
	'years' => '1999-2005',
	},
	## Legacy 96.43.xx
	{'arch' => 'Celsius',
	'ids' => '0110|0111|0112|0113|01a0',
	'code' => 'NV1x',
	'kernel' => '3.6',
	'legacy' => 1,
	'process' => 'TSMC 150-220nm',
	'release' => '96.43.23',
	'series' => '96.43.xx',
	'status' => main::message('nv-legacy-eol','2012-09-xx'),
	'xorg' => '1.12',
	'years' => '1999-2005',
	},
	{'arch' => 'Kelvin',
	'ids' => '0170|0171|0172|0173|0174|0175|0176|0177|0178|0179|017a|017c|017d|' .
	'0181|0182|0183|0185|0188|018a|018b|018c|01f0|0200|0201|0202|0203|0250|0251|' .
	'0253|0258|0259|025b|0280|0281|0282|0286|0288|0289|028c',
	'code' => 'NV2x',
	'kernel' => '3.6',
	'legacy' => 1,
	'process' => 'TSMC 150nm',
	'release' => '96.43.23',
	'series' => '96.43.xx',
	'status' => main::message('nv-legacy-eol','2012-09-xx'),
	'xorg' => '1.12',
	'years' => '2001-2003',
	},
	## Legacy 173.14.xx
	# process: IBM 130, TSMC 130-150
	{'arch' => 'Rankine',
	'ids' => '00fa|00fb|00fc|00fd|00fe|0301|0302|0308|0309|0311|0312|0314|031a|' .
	'031b|031c|0320|0321|0322|0323|0324|0325|0326|0327|0328|032a|032b|032c|032d|' .
	'0330|0331|0332|0333|0334|0338|033f|0341|0342|0343|0344|0347|0348|034c|034e',
	'code' => 'NV3x',
	'kernel' => '3.12',
	'legacy' => 1,
	'process' => '130-150nm',
	'release' => '173.14.39',
	'series' => '173.14.xx',
	'status' => main::message('nv-legacy-eol','2013-12-xx'),
	'xorg' => '1.15',
	'years' => '2003-2005',
	},
	## Legacy 304.xx
	# code: hard to get these, roughly MCP[567]x/NV4x/G7x
	# process: IBM 130, TSMC 90-110
	{'arch' => 'Curie',
	'ids' => '0040|0041|0042|0043|0044|0045|0046|0047|0048|004e|0090|0091|0092|' .
	'0093|0095|0098|0099|009d|00c0|00c1|00c2|00c3|00c8|00c9|00cc|00cd|00ce|00f1|' .
	'00f2|00f3|00f4|00f5|00f6|00f8|00f9|0140|0141|0142|0143|0144|0145|0146|0147|' .
	'0148|0149|014a|014c|014d|014e|014f|0160|0161|0162|0163|0164|0165|0166|0167|' .
	'0168|0169|016a|01d0|01d1|01d2|01d3|01d6|01d7|01d8|01da|01db|01dc|01dd|01de|' .
	'01df|0211|0212|0215|0218|0221|0222|0240|0241|0242|0244|0245|0247|0290|0291|' .
	'0292|0293|0294|0295|0297|0298|0299|029a|029b|029c|029d|029e|029f|02e0|02e1|' .
	'02e2|02e3|02e4|038b|0390|0391|0392|0393|0394|0395|0397|0398|0399|039c|039e|' .
	'03d0|03d1|03d2|03d5|03d6|0531|0533|053a|053b|053e|07e0|07e1|07e2|07e3|07e5',
	'code' => '', 
	'kernel' => '4.13',
	'legacy' => 1,
	'process' => '90-130nm', 
	'release' => '304.137',
	'series' => '304.xx',
	'status' => main::message('nv-legacy-eol','2017-09-xx'),
	'xorg' => '1.19',
	'years' => '2003-2013',
	},
	## Legacy 340.xx
	# these are both Tesla and Tesla 2.0
	# code: not clear, 8800/GT2xx/maybe G7x
	# years: 2006-2010 Tesla 2007-2013 Tesla 2.0
	{'arch' => 'Tesla',
	'ids' => '0191|0193|0194|0197|019d|019e|0400|0401|0402|0403|0404|0405|0406|' .
	'0407|0408|0409|040a|040b|040c|040d|040e|040f|0410|0420|0421|0422|0423|0424|' .
	'0425|0426|0427|0428|0429|042a|042b|042c|042d|042e|042f|05e0|05e1|05e2|05e3|' .
	'05e6|05e7|05ea|05eb|05ed|05f8|05f9|05fd|05fe|05ff|0600|0601|0602|0603|0604|' .
	'0605|0606|0607|0608|0609|060a|060b|060c|060d|060f|0610|0611|0612|0613|0614|' .
	'0615|0617|0618|0619|061a|061b|061c|061d|061e|061f|0621|0622|0623|0625|0626|' .
	'0627|0628|062a|062b|062c|062d|062e|0630|0631|0632|0635|0637|0638|063a|0640|' .
	'0641|0643|0644|0645|0646|0647|0648|0649|064a|064b|064c|0651|0652|0653|0654|' .
	'0655|0656|0658|0659|065a|065b|065c|06e0|06e1|06e2|06e3|06e4|06e5|06e6|06e7|' .
	'06e8|06e9|06ea|06eb|06ec|06ef|06f1|06f8|06f9|06fa|06fb|06fd|06ff|0840|0844|' .
	'0845|0846|0847|0848|0849|084a|084b|084c|084d|084f|0860|0861|0862|0863|0864|' .
	'0865|0866|0867|0868|0869|086a|086c|086d|086e|086f|0870|0871|0872|0873|0874|' .
	'0876|087a|087d|087e|087f|08a0|08a2|08a3|08a4|08a5|0a20|0a22|0a23|0a26|0a27|' .
	'0a28|0a29|0a2a|0a2b|0a2c|0a2d|0a32|0a34|0a35|0a38|0a3c|0a60|0a62|0a63|0a64|' .
	'0a65|0a66|0a67|0a68|0a69|0a6a|0a6c|0a6e|0a6f|0a70|0a71|0a72|0a73|0a74|0a75|' .
	'0a76|0a78|0a7a|0a7c|0ca0|0ca2|0ca3|0ca4|0ca5|0ca7|0ca8|0ca9|0cac|0caf|0cb0|' .
	'0cb1|0cbc|10c0|10c3|10c5|10d8',
	'code' => '', 
	'kernel' => '5.4',
	'legacy' => 1,
	'process' => '40-80nm',
	'release' => '340.108',
	'series' => '340.xx',
	'status' => main::message('nv-legacy-eol','2019-12-xx'),
	'xorg' => '1.20',
	'years' => '2006-2013',
	},
	## Legacy 367.xx
	{'arch' => 'Kepler',
	'ids' => '0fef|0ff2|11bf',
	'code' => 'GKxxx',
	'kernel' => '5.4',
	'legacy' => 1,
	'process' => 'TSMC 28nm',
	'release' => '',
	'series' => '367.xx',
	'status' => main::message('nv-legacy-eol','2017'),
	'xorg' => '1.20',
	'years' => '2012-2018',
	},
	## Legacy 390.xx
	# this is Fermi, Fermi 2.0
	{'arch' => 'Fermi',
	'ids' => '06c0|06c4|06ca|06cd|06d1|06d2|06d8|06d9|06da|06dc|06dd|06de|06df|' .
	'0dc0|0dc4|0dc5|0dc6|0dcd|0dce|0dd1|0dd2|0dd3|0dd6|0dd8|0dda|0de0|0de1|0de2|' .
	'0de3|0de4|0de5|0de7|0de8|0de9|0dea|0deb|0dec|0ded|0dee|0def|0df0|0df1|0df2|' .
	'0df3|0df4|0df5|0df6|0df7|0df8|0df9|0dfa|0dfc|0e22|0e23|0e24|0e30|0e31|0e3a|' .
	'0e3b|0f00|0f01|0f02|0f03|1040|1042|1048|1049|104a|104b|104c|1050|1051|1052|' .
	'1054|1055|1056|1057|1058|1059|105a|105b|107c|107d|1080|1081|1082|1084|1086|' .
	'1087|1088|1089|108b|1091|1094|1096|109a|109b|1140|1200|1201|1203|1205|1206|' .
	'1207|1208|1210|1211|1212|1213|1241|1243|1244|1245|1246|1247|1248|1249|124b|' .
	'124d|1251',
	'code' => 'GF1xx',
	'kernel' => '6.0',
	'legacy' => 1,
	'process' => '40/28nm',
	'release' => '390.157',
	'series' => '390.xx+',
	'status' => main::message('nv-legacy-eol','2022-11-22'),
	'xorg' => '1.21',
	'years' => '2010-2016',
	},
	## Legacy 470.xx
	{'arch' => 'Fermi 2',
	'ids' => '0fec|1281|1289|128b|1295|1298',
	'code' => 'GF119/GK208',
	'kernel' => '',
	'legacy' => 1,
	'process' => 'TSMC 28nm',
	'release' => '',
	'series' => '470.xx+',
	'status' => main::message('nv-legacy-active','2024-09-xx'),
	'xorg' => '',
	'years' => '2010-2016',
	},
	# GT 720M and 805A/810A are the same cpu id.
	# years: 2012-2018 Kepler 2013-2015 Kepler 2.0
	{'arch' => 'Kepler',
	'ids' => '0fc6|0fc8|0fc9|0fcd|0fce|0fd1|0fd2|0fd3|0fd4|0fd5|0fd8|0fd9|0fdf|' .
	'0fe0|0fe1|0fe2|0fe3|0fe4|0fe9|0fea|0fed|0fee|0ff6|0ff8|0ff9|0ffa|0ffb|0ffc|' .
	'0ffd|0ffe|0fff|1001|1004|1005|1007|1008|100a|100c|1021|1022|1023|1024|1026|' .
	'1027|1028|1029|102a|102d|103a|103c|1180|1183|1184|1185|1187|1188|1189|118a|' .
	'118e|118f|1193|1194|1195|1198|1199|119a|119d|119e|119f|11a0|11a1|11a2|11a3|' .
	'11a7|11b4|11b6|11b7|11b8|11ba|11bc|11bd|11be|11c0|11c2|11c3|11c4|11c5|11c6|' .
	'11c8|11cb|11e0|11e1|11e2|11e3|11fa|11fc|1280|1282|1284|1286|1287|1288|1290|' .
	'1291|1292|1293|1295|1296|1299|129a|12b9|12ba',
	'code' => 'GKxxx',
	'kernel' => '',
	'legacy' => 1,
	'process' => 'TSMC 28nm',
	'release' => '',
	'series' => '470.xx+',
	'status' => main::message('nv-legacy-active','2024-09-xx'),
	'xorg' => '',
	'years' => '2012-2018',
	},
	## Current Active Series
	# load microarch data, as stuff goes legacy, these will form new legacy items.
	{'arch' => 'Maxwell',
	'ids' => '1340|1341|1344|1346|1347|1348|1349|134b|134d|134e|134f|137a|137b|' .
	'1380|1381|1382|1390|1391|1392|1393|1398|1399|139a|139b|139c|139d|13b0|13b1|' .
	'13b2|13b3|13b4|13b6|13b9|13ba|13bb|13bc|13c0|13c2|13d7|13d8|13d9|13da|13f0|' .
	'13f1|13f2|13f3|13f8|13f9|13fa|13fb|1401|1402|1406|1407|1427|1430|1431|1436|' .
	'1617|1618|1619|161a|1667|174d|174e|179c|17c8|17f0|17f1|17fd|1c90|1d10|1d12',
	'code' => 'GMxxx',
	'kernel' => '',
	'legacy' => 0,
	'process' => 'TSMC 28nm',
	'release' => '',
	'series' => '545.xx+',
	'status' => main::message('nv-current-eol',$date,'2026-12-xx'),
	'xorg' => '',
	'years' => '2014-2019',
	},
	{'arch' => 'Pascal',
	'ids' => '15f0|15f7|15f8|15f9|17c2|1b00|1b02|1b06|1b30|1b38|1b80|1b81|1b82|' .
	'1b83|1b84|1b87|1ba0|1ba1|1ba2|1bb0|1bb1|1bb3|1bb4|1bb5|1bb6|1bb7|1bb8|1bb9|' .
	'1bbb|1bc7|1be0|1be1|1c02|1c03|1c04|1c06|1c07|1c09|1c20|1c21|1c22|1c23|1c30|' .
	'1c31|1c60|1c61|1c62|1c81|1c82|1c83|1c8c|1c8d|1c8f|1c90|1c91|1c92|1c94|1c96|' .
	'1cb1|1cb2|1cb3|1cb6|1cba|1cbb|1cbc|1cbd|1cfa|1cfb|1d01|1d02|1d11|1d13|1d16|' .
	'1d33|1d34|1d52',
	'code' => 'GP10x',
	'kernel' => '',
	'legacy' => 0,
	'process' => 'TSMC 16nm',
	'release' => '',
	'series' => '545.xx+',
	'status' => main::message('nv-current-eol',$date,'2026-12-xx'),
	'xorg' => '',
	'years' => '2016-2021',
	},
	{'arch' => 'Volta',
	'ids' => '1d81|1db1|1db3|1db4|1db5|1db6|1db7|1db8|1dba|1df0|1df2|1df6|1fb0',
	'code' => 'GV1xx',
	'kernel' => '',
	'legacy' => 0,
	'process' => 'TSMC 12nm',
	'release' => '',
	'series' => '545.xx+',
	'status' => main::message('nv-current-eol',$date,'2026-12-xx'),
	'xorg' => '',
	'years' => '2017-2020',
	},
	{'arch' => 'Turing',
	'ids' => '1e02|1e04|1e07|1e09|1e30|1e36|1e78|1e81|1e82|1e84|1e87|1e89|1e90|' .
	'1e91|1e93|1eb0|1eb1|1eb5|1eb6|1ec2|1ec7|1ed0|1ed1|1ed3|1ef5|1f02|1f03|1f06|' .
	'1f07|1f08|1f0a|1f0b|1f10|1f11|1f12|1f14|1f15|1f36|1f42|1f47|1f50|1f51|1f54|' .
	'1f55|1f76|1f82|1f83|1f91|1f95|1f96|1f97|1f98|1f99|1f9c|1f9d|1f9f|1fa0|1fb0|' .
	'1fb1|1fb2|1fb6|1fb7|1fb8|1fb9|1fba|1fbb|1fbc|1fdd|1ff0|1ff2|1ff9|2182|2184|' .
	'2187|2188|2189|2191|2192|21c4|21d1|25a6|25a7|25a9|25aa|25ad|25ed|28b0|28b8|' .
	'28f8',
	'code' => 'TUxxx',
	'kernel' => '',
	'legacy' => 0,
	'process' => 'TSMC 12nm FF',
	'release' => '',
	'series' => '550.xx+',
	'status' => main::message('nv-current-eol',$date,'2026-12-xx'),
	'xorg' => '',
	'years' => '2018-2022',
	},
	{'arch' => 'Ampere',
	'ids' => '20b0|20b2|20b3|20b5|20b6|20b7|20bd|20f1|20f3|20f5|20f6|20fd|2203|' .
	'2204|2206|2207|2208|220a|220d|2216|2230|2231|2232|2233|2235|2236|2237|2238|' .
	'2414|2420|2438|2460|2482|2484|2486|2487|2488|2489|248a|249c|249d|24a0|24b0|' .
	'24b1|24b6|24b7|24b8|24b9|24ba|24bb|24c7|24c9|24dc|24dd|24e0|24fa|2503|2504|' .
	'2507|2508|2520|2521|2523|2531|2544|2560|2563|2571|2582|2584|25a0|25a2|25a5|' .
	'25ab|25ac|25b6|25b8|25b9|25ba|25bb|25bc|25bd|25e0|25e2|25e5|25ec|25f9|25fa|' .
	'25fb|2838',
	'code' => 'GAxxx',
	'kernel' => '',
	'legacy' => 0,
	'process' => 'TSMC n7 (7nm)',
	'release' => '',
	'series' => '550.xx+',
	'status' => main::message('nv-current-eol',$date,'2026-12-xx'),
	'xorg' => '',
	'years' => '2020-2023',
	},
	{'arch' => 'Hopper',
	'ids' => '2321|2322|2324|2329|2330|2331|2339|233a|2342',
	'code' => 'GH1xx',
	'kernel' => '',
	'legacy' => 0,
	'process' => 'TSMC n4 (5nm)',
	'release' => '',
	'series' => '545.xx+',
	'status' => $status_current,
	'xorg' => '',
	'years' => '2022+',
	},
	{'arch' => 'Lovelace',
	'ids' => '2684|2685|26b1|26b2|26b3|26b5|26b9|26ba|2702|2704|2705|2709|2717|' .
	'2730|2757|2770|2782|2783|2786|2788|27a0|27b0|27b1|27b2|27b6|27b8|27ba|27bb|' .
	'27e0|27fb|2803|2805|2808|2820|2860|2882|28a0|28a1|28b9|28ba|28bb|28e0|28e1',
	'code' => 'AD1xx',
	'kernel' => '',
	'legacy' => 0,
	'process' => 'TSMC n4 (5nm)',
	'release' => '',
	'series' => '550.xx+',
	'status' => $status_current,
	'xorg' => '',
	'years' => '2022+',
	},
	],
}

sub gpu_data {
	eval $start if $b_log;
	my ($v_id,$p_id,$name) = @_;
	my ($gpu,$gpu_data,$b_nv);
	if ($v_id eq '1002'){
		set_amd_data() if !$gpu_amd;
		$gpu = $gpu_amd;
	}
	elsif ($v_id eq '8086'){
		set_intel_data() if !$gpu_intel;
		$gpu = $gpu_intel;
	}
	else {
		set_nv_data() if !$gpu_nv;
		$gpu = $gpu_nv;
		$b_nv = 1;
	}
	$gpu_data = get_gpu_data($gpu,$p_id,$name);
	eval $end if $b_log;
	return ($gpu_data,$b_nv);
}

sub get_gpu_data {
	eval $start if $b_log;
	my ($gpu,$p_id,$name) = @_;
	my ($info);
	# Don't use reverse because if product ID is matched, we want that, not a looser
	# regex match. Tried with reverse and led to false matches.
	foreach my $item (reverse @$gpu){
		next if !$item->{'ids'} && (!$item->{'pattern'} || !$name);
		if (($item->{'ids'} && $p_id =~ /^($item->{'ids'})$/) ||
		(!$item->{'ids'} && $item->{'pattern'} && 
		$name =~ /\b($item->{'pattern'})\b/)){
			$info = {
			'arch' => $item->{'arch'},
			'code' => $item->{'code'},
			'kernel' => $item->{'kernel'},
			'legacy' => $item->{'legacy'},
			'process' => $item->{'process'},
			'release' => $item->{'release'},
			'series' => $item->{'series'},
			'status' => $item->{'status'},
			'xorg' => $item->{'xorg'},
			'years' => $item->{'years'},
			};
			last;
		}
	}
	if (!$info){
		$info->{'status'} = main::message('unknown-device-id');
	}
	main::log_data('dump','%info',$info) if $b_log;
	print "Raw \$info data: ", Data::Dumper::Dumper $info if $dbg[49];
	eval $end if $b_log;
	return $info;
}

## MONITOR DATA ##
sub set_monitors_sys {
	eval $start if $b_log;
	my $pattern = '/sys/class/drm/card[0-9]/device/driver/module/drivers/*';
	my @cards_glob = main::globber($pattern);
	$pattern = '/sys/class/drm/card*-*/{connector_id,edid,enabled,status,modes}';
	my @ports_glob = main::globber($pattern);
	# print Data::Dumper::Dumper \@cards_glob;
	# print Data::Dumper::Dumper \@ports_glob;
	my ($card,%cards,@data,$file,$item,$path,$port);
	foreach $file (@cards_glob){
		next if ! -e $file;
		if ($file =~ m|^/sys/class/drm/(card\d+)/.+?/drivers/(\S+):(\S+)$|){
			push(@{$cards{$1}},[$2,$3]);
		}
	}
	# print Data::Dumper::Dumper \%cards;
	foreach $file (sort @ports_glob){
		next if ! -r $file;
		$item = $file;
		$item =~ s|(/.*/(card\d+)-([^/]+))/(.+)||;
		$path = $1;
		$card = $2;
		$port = $3;
		$item = $4;
		next if !$1;
		$monitor_ids = {} if !$monitor_ids;
		$monitor_ids->{$port}{'monitor'} = $port;
		if (!$monitor_ids->{$port}{'drivers'} && $cards{$card}){
			foreach my $info (@{$cards{$card}}){
				push(@{$monitor_ids->{$port}{'drivers'}},$info->[1]);
			}
		}
		$monitor_ids->{$port}{'path'} = readlink($path);
		$monitor_ids->{$port}{'path'} =~ s|^\.\./\.\.|/sys|;
		if ($item eq 'status' || $item eq 'enabled'){
			# print "$file\n";
			$monitor_ids->{$port}{$item} = main::reader($file,'strip',0);
		}
		elsif ($item eq 'connector_id'){
			$monitor_ids->{$port}{'connector-id'} = main::reader($file,'strip',0);
		}
		# arm: U:1680x1050p-0
		elsif ($item eq 'modes'){
			@data = main::reader($file,'strip');
			next if !@data;
			# modes has repeat values, probably because kernel doesn't show hz
			main::uniq(\@data);
			$monitor_ids->{$port}{'modes'} = [@data];
		}
		elsif ($item eq 'edid'){
			next if -s $file;
			monitor_edid_data($file,$port);
		}
	}
	main::log_data('dump','$ports ref',$monitor_ids) if $b_log;
	print 'monitor_sys_data(): ', Data::Dumper::Dumper $monitor_ids if $dbg[44];
	eval $end if $b_log;
}

sub monitor_edid_data {
	eval $start if $b_log;
	my ($file,$port) = @_;
	my (@data);
	open my $fh, '<:raw', $file or return; # it failed, give up, we don't care why
	my $edid_raw = do { local $/; <$fh> };
	return if !$edid_raw;
	my $edid = ParseEDID::parse_edid($edid_raw,$dbg[47]);
	main::log_data('dump','Parse::EDID',$edid) if $b_log;
	print 'parse_edid(): ', Data::Dumper::Dumper $edid if $dbg[44];
	return if !$edid || ref $edid ne 'HASH' || !%$edid;
	$monitor_ids->{$port}{'build-date'} = $edid->{'year'};
	if ($edid->{'color_characteristics'}){
		$monitor_ids->{$port}{'colors'} = $edid->{'color_characteristics'};
	}
	if ($edid->{'gamma'}){
		$monitor_ids->{$port}{'gamma'} = ($edid->{'gamma'}/100 + 0);
	}
	if ($edid->{'monitor_name'} || $edid->{'manufacturer_name_nice'}){
		my $model = '';
		if ($edid->{'manufacturer_name_nice'}){
			$model = $edid->{'manufacturer_name_nice'};
		}
		if ($edid->{'monitor_name'}){
			$model .= ' ' if $model;
			$model .= $edid->{'monitor_name'};
		}
		elsif ($model && $edid->{'product_code_h'}){
			$model .= ' ' . $edid->{'product_code_h'};
		}
		$monitor_ids->{$port}{'model'} = main::remove_duplicates(main::clean($model));
	}
	elsif ($edid->{'manufacturer_name'} && $edid->{'product_code_h'}){
		$monitor_ids->{$port}{'model-id'} = $edid->{'manufacturer_name'} . ' ';
		$monitor_ids->{$port}{'model-id'} .= $edid->{'product_code_h'};
	}
	# construct to match xorg values
	if ($edid->{'manufacturer_name'} && $edid->{'product_code'}){
		my $id = $edid->{'manufacturer_name'} . sprintf('%x',$edid->{'product_code'});
		$monitor_ids->{$port}{$id} = ($edid->{'serial_number'}) ? $edid->{'serial_number'}: '';
	}
	if ($edid->{'diagonal_size'}){
		$monitor_ids->{$port}{'diagonal-m'} = sprintf('%.0f',($edid->{'diagonal_size'}*25.4)) + 0;
		$monitor_ids->{$port}{'diagonal'} = sprintf('%.1f',$edid->{'diagonal_size'}) + 0;
	}
	if ($edid->{'ratios'}){
		$monitor_ids->{$port}{'ratio'} = join(', ', @{$edid->{'ratios'}});
	}
	if ($edid->{'detailed_timings'}){
		if ($edid->{'detailed_timings'}[0]{'horizontal_active'}){
			$monitor_ids->{$port}{'res-x'} = $edid->{'detailed_timings'}[0]{'horizontal_active'};
		}
		if ($edid->{'detailed_timings'}[0]{'vertical_active'}){
			$monitor_ids->{$port}{'res-y'} = $edid->{'detailed_timings'}[0]{'vertical_active'};
		}
		if ($edid->{'detailed_timings'}[0]{'horizontal_image_size'}){
			$monitor_ids->{$port}{'size-x'} = $edid->{'detailed_timings'}[0]{'horizontal_image_size'};
			$monitor_ids->{$port}{'size-x-i'} = $edid->{'detailed_timings'}[0]{'horizontal_image_size_i'};
		}
		if ($edid->{'detailed_timings'}[0]{'vertical_image_size'}){
			$monitor_ids->{$port}{'size-y'} = $edid->{'detailed_timings'}[0]{'vertical_image_size'};
			$monitor_ids->{$port}{'size-y-i'} = $edid->{'detailed_timings'}[0]{'vertical_image_size_i'};
		}
		if ($edid->{'detailed_timings'}[0]{'horizontal_dpi'}){
			$monitor_ids->{$port}{'dpi'} = sprintf('%.0f',$edid->{'detailed_timings'}[0]{'horizontal_dpi'}) + 0;
		}
	}
	if ($edid->{'serial_number'} || $edid->{'serial_number2'}){
		# this looks much more like a real serial than the default: serial_number
		if ($edid->{'serial_number2'} && @{$edid->{'serial_number2'}}){
			$monitor_ids->{$port}{'serial'} = main::clean_dmi($edid->{'serial_number2'}[0]);
		}
		elsif ($edid->{'serial_number'}){
			$monitor_ids->{$port}{'serial'} = main::clean_dmi($edid->{'serial_number'}); 
		}
	}
	# this will be an array reference of one or more edid errors
	if ($edid->{'edid_errors'}){
		$monitor_ids->{$port}{'edid-errors'} = $edid->{'edid_errors'};
	}
	# this will be an array reference of one or more edid warnings
	if ($edid->{'edid_warnings'}){
		$monitor_ids->{$port}{'edid-warnings'} = $edid->{'edid_warnings'};
	}
	eval $end if $b_log;
}

sub advanced_monitor_data {
	eval $start if $b_log;
	my ($monitors,$layouts) = @_;
	my (@horiz,@vert);
	my $position = '';
	# then see if we can locate a default position primary monitor
	foreach my $key (keys %$monitors){
		next if !defined $monitors->{$key}{'pos-x'} || !defined $monitors->{$key}{'pos-y'};
		# this is the only scenario we can guess at if no primary detected
		if (!$b_primary && !$monitors->{$key}{'primary'} &&
		 $monitors->{$key}{'pos-x'} == 0 && $monitors->{$key}{'pos-y'} == 0){
			$monitors->{$key}{'position'} = 'primary';
			$monitors->{$key}{'primary'} = $monitors->{$key}{'monitor'};
		}
		if (!grep {$monitors->{$key}{'pos-x'} == $_} @horiz){
			push(@horiz,$monitors->{$key}{'pos-x'});
		}
		if (!grep {$monitors->{$key}{'pos-y'} == $_} @vert){
			push(@vert,$monitors->{$key}{'pos-y'});
		}
	}
	# we need NUMERIC sort, because positions can be less than 1000!
	@horiz = sort {$a <=> $b} @horiz;
	@vert =sort {$a <=> $b} @vert;
	my ($h,$v) = (scalar(@horiz),scalar(@vert));
	# print Data::Dumper::Dumper \@horiz;
	# print Data::Dumper::Dumper \@vert;
	# print Data::Dumper::Dumper $layouts;
	# print 'mon advanced monitor_map: ', Data::Dumper::Dumper $monitor_map;
	foreach my $key (keys %$monitors){
		# disabled monitor may  not have pos-x/pos-y, so skip
		if (@horiz && @vert && (scalar @horiz > 1 || scalar @vert > 1) && 
		defined $monitors->{$key}{'pos-x'} && defined $monitors->{$key}{'pos-y'}){
			$monitors->{$key}{'position'} ||= '';
			$position = '';
			$position = get_monitor_position($monitors->{$key},\@horiz,\@vert);
			$position = $layouts->[$v][$h]{$position} if $layouts->[$v][$h]{$position};
			$monitors->{$key}{'position'} .= ',' if $monitors->{$key}{'position'};
			$monitors->{$key}{'position'} .= $position;
		}
		my $mon_mapped = ($monitor_map) ? $monitor_map->{$monitors->{$key}{'monitor'}} : undef;
		# these are already set for monitor_ids, only need this for Xorg data.
		if ($mon_mapped && $monitor_ids->{$mon_mapped}){
			# note: xorg drivers can be different than gpu drivers
			$monitors->{$key}{'drivers'} = gpu_drivers_sys($mon_mapped);
			$monitors->{$key}{'build-date'} = $monitor_ids->{$mon_mapped}{'build-date'};
			$monitors->{$key}{'colors'} = $monitor_ids->{$mon_mapped}{'colors'};
			$monitors->{$key}{'diagonal'} = $monitor_ids->{$mon_mapped}{'diagonal'};
			$monitors->{$key}{'diagonal-m'} = $monitor_ids->{$mon_mapped}{'diagonal-m'};
			$monitors->{$key}{'gamma'} = $monitor_ids->{$mon_mapped}{'gamma'};
			$monitors->{$key}{'modes'} = $monitor_ids->{$mon_mapped}{'modes'};
			$monitors->{$key}{'model'} = $monitor_ids->{$mon_mapped}{'model'};
			$monitors->{$key}{'color-characteristics'} = $monitor_ids->{$mon_mapped}{'color-characteristics'};
			if (!defined $monitors->{$key}{'size-x'} && $monitor_ids->{$mon_mapped}{'size-x'}){
				$monitors->{$key}{'size-x'} = $monitor_ids->{$mon_mapped}{'size-x'};
				$monitors->{$key}{'size-x-i'} = $monitor_ids->{$mon_mapped}{'size-x-i'};
			}
			if (!defined $monitors->{$key}{'size-y'} && $monitor_ids->{$mon_mapped}{'size-y'}){
				$monitors->{$key}{'size-y'} = $monitor_ids->{$mon_mapped}{'size-y'};
				$monitors->{$key}{'size-y-i'} = $monitor_ids->{$mon_mapped}{'size-y-i'};
			}
			if (!defined $monitors->{$key}{'dpi'} && $monitor_ids->{$mon_mapped}{'dpi'}){
				$monitors->{$key}{'dpi'} = $monitor_ids->{$mon_mapped}{'dpi'};
			}
			if ($monitor_ids->{$mon_mapped}{'model-id'}){
				$monitors->{$key}{'model-id'} = $monitor_ids->{$mon_mapped}{'model-id'};
			}
			if ($monitor_ids->{$mon_mapped}{'edid-errors'}){
				$monitors->{$key}{'edid-errors'} = $monitor_ids->{$mon_mapped}{'edid-errors'};
			}
			if ($monitor_ids->{$mon_mapped}{'edid-warnings'}){
				$monitors->{$key}{'edid-warnings'} = $monitor_ids->{$mon_mapped}{'edid-warnings'};
			}
			if ($monitor_ids->{$mon_mapped}{'enabled'} && 
			$monitor_ids->{$mon_mapped}{'enabled'} eq 'disabled'){
				$monitors->{$key}{'disabled'} = $monitor_ids->{$mon_mapped}{'enabled'};
			}
			$monitors->{$key}{'ratio'} = $monitor_ids->{$mon_mapped}{'ratio'};
			$monitors->{$key}{'serial'} = $monitor_ids->{$mon_mapped}{'serial'};
		}
		# now swap the drm id for the display server id if they don't match
		if ($mon_mapped && $mon_mapped ne $monitors->{$key}{'monitor'}){
			$monitors->{$key}{'monitor-mapped'} = $monitors->{$key}{'monitor'};
			$monitors->{$key}{'monitor'} = $mon_mapped;
		}
	}
	# not printing out primary if Screen has only 1 Monitor
	if (scalar keys %$monitors == 1){
		my @keys = keys %$monitors;
		$monitors->{$keys[0]}{'position'} = undef;
	}
	print Data::Dumper::Dumper $monitors if $dbg[45];
	eval $end if $b_log;
}

# Clear out all disabled or not connected monitor ports
sub set_active_monitors {
	eval $start if $b_log;
	foreach my $key (keys %$monitor_ids){
		if (!$monitor_ids->{$key}{'status'} ||
		$monitor_ids->{$key}{'status'} ne 'connected'){
			delete $monitor_ids->{$key};
		}
	}
	# print 'active monitors: ', Data::Dumper::Dumper $monitor_ids;
	eval $end if $b_log;
}

sub get_monitor_position {
	eval $start if $b_log;
	my ($monitor,$horiz,$vert) = @_;
	my ($i,$position) = (1,'');
	foreach (@$vert){
		if ($_ == $monitor->{'pos-y'}){
			$position = $i . '-';
			last;
		}
		$i++;
	}
	$i = 1;
	foreach (@$horiz){
		if ($_ == $monitor->{'pos-x'}){
			$position .= $i;
			last;
		}
		$i++;
	}
	main::log_data('data','pos-raw: ' . $position) if $b_log;
	eval $end if $b_log;
	return $position;
}

sub set_monitor_layouts {
	my ($layouts) = @_;
	$layouts->[1][2] = {'1-1' => 'left','1-2' => 'right'};
	$layouts->[1][3] = {'1-1' => 'left','1-2' => 'center','1-3' => 'right'};
	$layouts->[1][4] = {'1-1' => 'left','1-2' => 'center-l','1-3' => 'center-r',
	 '1-4' => 'right'};
	$layouts->[2][1] = {'1-1' => 'top','2-1' => 'bottom'};
	$layouts->[2][2] = {'1-1' => 'top-left','1-2' => 'top-right',
	 '2-1' => 'bottom-l','2-2' => 'bottom-r'};
	$layouts->[2][3] = {'1-1' => 'top-left','1-2' => 'top-center','1-3' => 'top-right',
	 '2-1' => 'bottom-l','2-2' => 'bottom-c','2-3' => 'bottom-r'};
	$layouts->[3][1] = {'1-1' => 'top','2-1' => 'middle','3-1' => 'bottom'};
	$layouts->[3][2] = {'1-1' => 'top-left','1-2' => 'top-right',
	'2-1' => 'middle-l','2-2' => 'middle-r',
	'3-1' => 'bottom-l','3-2' => 'bottom-r'};
	$layouts->[3][3] = {'1-1' => 'top-left','1-2' => 'top-center',,'1-3' => 'top-right',
	 '2-1' => 'middle-l','2-2' => 'middle-c','2-3' => 'middle-r',
	 '3-1' => 'bottom-l','3-2' => 'bottom-c','3-3' => 'bottom-r'};
}

# This is required to resolve the situation where some xorg drivers change 
# the kernel ID for the port to something slightly different, amdgpu in particular.
# Note: connector_id if available from xrandr and /sys allow for matching.
sub map_monitor_ids {
	eval $start if $b_log;
	my ($display_ids) = @_;
	return if !$monitor_ids;
	my (@sys_ids,@unmatched_display,@unmatched_sys);
	@$display_ids = sort {lc($a->[0]) cmp lc($b->[0])} @$display_ids;
	foreach my $d_id (@$display_ids){
		push(@unmatched_display,$d_id->[0]);
	}
	foreach my $key (sort keys %$monitor_ids){
		if ($monitor_ids->{$key}{'status'} eq 'connected'){
			push(@sys_ids,[$key,$monitor_ids->{$key}{'connector-id'}]);
			push(@unmatched_sys,$key);
		}
	}
	# @sys_ids = ('DVI-I-1','eDP-1','VGA-1');
	main::log_data('dump','@sys_ids',\@sys_ids) if $b_log;
	main::log_data('dump','$xrandr_ids ref',$display_ids) if $b_log;
	print 'sys: ', Data::Dumper::Dumper \@sys_ids if $dbg[45];
	print 'display: ', Data::Dumper::Dumper $display_ids if $dbg[45];
	return if scalar @sys_ids != scalar @$display_ids;
	$monitor_map = {};
	# known patterns: s: DP-1 d: DisplayPort-0; s: DP-1 d: DP1-1; s: DP-2 d: DP1-2;
	# s: HDMI-A-2 d: HDMI-A-1; s: HDMI-A-2 d: HDMI-2; s: DVI-1 d: DVI1; s: HDMI-1 d: HDMI1 
	# s: DVI-I-1 d: DVI0; s: VGA-1 d: VGA1; s: DP-1-1; d: DP-1-1;
	# s: eDP-1 d: eDP-1-1 (yes, reversed from normal deviation!); s: eDP-1 d: eDP
	# worst: s: DP-6 d: DP-2-3 (2 banks of 3 according to X); s: eDP-1 d: DP-4;
	# s: DP-3 d: DP-1-1; s: DP-4 d: DP-1-2
	# s: DP-3 d: DP-4 [yes, +1, not -]; 
	my ($d_1,$d_2,$d_m,$s_1,$s_2,$s_m);
	my $b_single = (scalar @sys_ids == 1) ? 1 : 0;
	my $pattern = '([A-Z]+)(-[A-Z]-\d+-\d+|-[A-Z]-\d+|-?\d+-\d+|-?\d+|)';
	for (my $i=0; $i < scalar @$display_ids; $i++){
		print "s: $sys_ids[$i]->[0] d: $display_ids->[$i][0]\n" if $dbg[45];
		my $b_match;
		# we're going for the connector match first
		if ($display_ids->[$i][1]){
			# for off case where they did not sort to same order
			foreach my $sys (@sys_ids){
				if (defined $sys->[1] && $sys->[1] == $display_ids->[$i][1]){
					$b_match = 1;
					$monitor_map->{$display_ids->[$i][0]} = $sys->[0];
					@unmatched_display = grep {$_ ne $display_ids->[$i][0]} @unmatched_display;
					@unmatched_sys = grep {$_ ne $sys->[0]} @unmatched_sys;
					last;
				}
			}
		}
		# try 1: /^([A-Z]+)(-[AB]|-[ADI]|-[ADI]-\d+?|-\d+?)?(-)?(\d+)$/i
		if (!$b_match && $display_ids->[$i][0] =~ /^$pattern$/i){
			$d_1 = $1;
			$d_2 = ($2) ? $2 : '';
			$d_2 =~ /(\d+)?$/;
			$d_m = ($1) ? $1 : 0;
			$d_1 =~ s/^DisplayPort/DP/i; # amdgpu...
			print " d1: $d_1 d2: $d_2 d3: $d_m\n" if $dbg[45];
			if ($sys_ids[$i]->[0] =~ /^$pattern$/i){
				$s_1 = $1;
				$s_2 = ($2) ? $2 : '';
				$s_2 =~ /(\d+)?$/;
				$s_m = ($1) ? $1 : 0;
				$d_1 = $s_1 if uc($d_1) eq 'XWAYLAND';
				print " d1: $d_1 s1: $s_1 dm: $d_m sm: $s_m \n" if $dbg[45];
				if ($d_1 eq $s_1 && ($d_m == $s_m || $d_m == ($s_m - 1))){
					$monitor_map->{$display_ids->[$i][0]} = $sys_ids[$i]->[0];
					@unmatched_display = grep {$_ ne $display_ids->[$i][0]} @unmatched_display;
					@unmatched_sys = grep {$_ ne $sys_ids[$i]->[0]} @unmatched_sys;
				}
			}
		}
		# in case of one unmatched, we'll dump this, and use the actual unmatched
		if (!$b_match && !$monitor_map->{$display_ids->[$i][0]}){
			# we're not even going to try, if there's 1 sys and 1 display, just use it!
			if ($b_single){
				$monitor_map->{$display_ids->[$i][0]} = $sys_ids[$i]->[0];
				(@unmatched_display,@unmatched_sys) = ();
			}
			else {
				$monitor_map->{$display_ids->[$i][0]} = main::message('monitor-id');
			}
		}
	}
	# we don't care at all what the pattern is, if there is 1 unmatched display 
	# out of 1 sys ids, we'll assume that is the one. This can only be assumed in
	# cases where only 1 monitor was not matched, otherwise it's just a guess.
	# obviously, if one of the matches was wrong, this will also be wrong, but 
	# thats' life when dealing with irrational data. DP is a particular problem.
	if (scalar @unmatched_sys == 1){
		$monitor_map->{$unmatched_display[0]} = $unmatched_sys[0];
	}
	main::log_data('dump','$monitor_map ref',$monitor_map) if $b_log;
	print Data::Dumper::Dumper $monitor_map if $dbg[45];
	eval $end if $b_log;
}

# Handle case of monitor on left or right edge, vertical that is.
# mm dimensiions are based on the default position of monitor as sold.
# very old systems may not have non 0 value for size x or y
# size, res x,y by reference
sub flip_size_x_y {
	eval $start if $b_log;
	my ($size_x,$size_y,$res_x,$res_y) = @_;
	if ((($$res_x/$$res_y > 1 && $$size_x/$$size_y < 1) || 
	($$res_x/$$res_y < 1 && $$size_x/$$size_y > 1))){
		($$size_x,$$size_y) = ($$size_y,$$size_x);
	}
	eval $end if $b_log;
}

## COMPOSITOR DATA ##
sub set_compositor_data {
	eval $start if $b_log;
	my $compositors = get_compositors();
	if (@$compositors){
		# these use different spelling or command for full data.
		my %custom = (
		'hyprland' => 'hyprctl',
		);
		my @data;
		foreach my $compositor (@$compositors){
			# gnome-shell is incredibly slow to return version
			if (($extra > 1 || $graphics{'protocol'} eq 'wayland' || $b_android) && 
			(!$show{'system'} || $compositor ne 'gnome-shell')){
				my $comp_lc = lc($compositor);
				$graphics{'compositors'} = [] if !$graphics{'compositors'};
				# if -S found wm/comp, this is already set so no need to run version again
				# note: -Sxxx shows wm v:, but -Gxx OR WL shows comp + v.
				if (!$comps{$comp_lc} || ($extra < 3 && !$comps{$comp_lc}->[1])){
					my $comp = ($custom{$comp_lc}) ? $custom{$comp_lc}: $compositor;
					push(@{$graphics{'compositors'}},[ProgramData::full($comp)]);
				}
				else {
					push(@{$graphics{'compositors'}},$comps{$comp_lc}); # already array ref
				}
			}
			else {
				$graphics{'compositors'} = [] if !$graphics{'compositors'};
				push(@{$graphics{'compositors'}},[(ProgramData::values($compositor))[3]]);
			}
		}
	}
	eval $end if $b_log;
}

sub get_compositors {
	eval $start if $b_log;
	PsData::set_de_wm() if !$loaded{'ps-gui'};
	my $comps = [];
	push(@$comps,@{$ps_data{'compositors-pure'}}) if @{$ps_data{'compositors-pure'}};
	push(@$comps,@{$ps_data{'de-wm-compositors'}}) if @{$ps_data{'de-wm-compositors'}};
	push(@$comps,@{$ps_data{'wm-compositors'}}) if @{$ps_data{'wm-compositors'}};
	@$comps = sort(@$comps) if @$comps;
	main::log_data('dump','$comps:', $comps) if $b_log;
	eval $end if $b_log;
	return $comps;
}

## UTILITIES ##
sub tty_data {
	eval $start if $b_log;
	my ($tty);
	if ($size{'term-cols'}){
		$tty = "$size{'term-cols'}x$size{'term-lines'}";
	}
	# this is broken
	elsif ($b_irc && $client{'console-irc'}){
		ShellData::console_irc_tty() if !$loaded{'con-irc-tty'};
		my $tty_working = $client{'con-irc-tty'};
		if ($tty_working ne '' && (my $program = main::check_program('stty'))){
			my $tty_arg = ($bsd_type) ? '-f' : '-F';
			# handle vtnr integers, and tty ID with letters etc.
			$tty_working = "tty$tty_working" if -e "/dev/tty$tty_working";
			$tty = (main::grabber("$program $tty_arg /dev/$tty_working size 2>/dev/null"))[0];
			if ($tty){
				my @temp = split(/\s+/, $tty);
				$tty = "$temp[1]x$temp[0]";
			}
		}
	}
	eval $end if $b_log;
	return $tty;
}
}

## LogicalItem
{