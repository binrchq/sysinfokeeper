package WeatherItem;

sub get {
	eval $start if $b_log;
	my $rows = [];
	my $num = 0;
	my $location = [];
	location_data($location);
	# print Data::Dumper::Dumper $location;exit;
	if (!$location->[0]){
		@$rows = ({
		main::key($num++,0,1,'Message') => main::message('weather-null','current location')
		});
	}
	else {
		my $weather = get_weather($location);
		if ($weather->{'error'}){
			@$rows = ({
			main::key($num++,0,1,'Message') => main::message('weather-error',$weather->{'error'})
			});
		}
		elsif (!$weather->{'weather'}){
			@$rows = ({
			main::key($num++,0,1,'Message') => main::message('weather-null','weather data')
			});
		}
		else {
			weather_output($rows,$location,$weather);
		}
	}
	if (!@$rows){
		@$rows = ({
		main::key($num++,0,1,'Message') => main::message('weather-null','weather data')
		});
	}
	eval $end if $b_log;
	return $rows;
}

sub weather_output {
	eval $start if $b_log;
	my ($rows,$location,$weather) = @_;
	my ($j,$num) = (0,0);
	my ($value);
	my ($conditions) = ('NA');
	$conditions = "$weather->{'weather'}";
	my $temp = process_unit(
	$weather->{'temp'},
	$weather->{'temp-c'},'C',
	$weather->{'temp-f'},'F');
	$j = scalar @$rows;
	push(@$rows, {
	main::key($num++,1,1,'Report') => '',
	main::key($num++,0,2,'temperature') => $temp,
	main::key($num++,0,2,'conditions') => $conditions,
	},);
	if ($extra > 0){
		my $pressure = process_unit(
		$weather->{'pressure'},
		$weather->{'pressure-mb'},'mb',
		$weather->{'pressure-in'},'in');
		my $wind = process_wind(
		$weather->{'wind'},
		$weather->{'wind-direction'},
		$weather->{'wind-mph'},
		$weather->{'wind-ms'},
		$weather->{'wind-gust-mph'},
		$weather->{'wind-gust-ms'});
		$rows->[$j]{main::key($num++,0,2,'wind')} = $wind;
		if ($extra > 1){
			if (defined $weather->{'cloud-cover'}){
				$rows->[$j]{main::key($num++,0,2,'cloud cover')} = $weather->{'cloud-cover'} . '%';
			}
			if ($weather->{'precip-1h-mm'} && defined $weather->{'precip-1h-in'}){
				$value = process_unit('',$weather->{'precip-1h-mm'},'mm',
				$weather->{'precip-1h-in'},'in');
				$rows->[$j]{main::key($num++,0,2,'precipitation')} = $value;
			}
			if ($weather->{'rain-1h-mm'} && defined $weather->{'rain-1h-in'}){
				$value = process_unit('',$weather->{'rain-1h-mm'},'mm',
				$weather->{'rain-1h-in'},'in');
				$rows->[$j]{main::key($num++,0,2,'rain')} = $value;
			}
			if ($weather->{'snow-1h-mm'} && defined $weather->{'snow-1h-in'}){
				$value = process_unit('',$weather->{'snow-1h-mm'},'mm',
				$weather->{'snow-1h-in'},'in');
				$rows->[$j]{main::key($num++,0,2,'snow')} = $value;
			}
		}
		$rows->[$j]{main::key($num++,0,2,'humidity')} = $weather->{'humidity'} . '%';
		if ($extra > 1){
			if ($weather->{'dewpoint'} || (defined $weather->{'dewpoint-c'} && 
			defined $weather->{'dewpoint-f'})){
				$value = process_unit(
				$weather->{'dewpoint'},
				$weather->{'dewpoint-c'},
				'C',
				$weather->{'dewpoint-f'},
				'F');
				$rows->[$j]{main::key($num++,0,2,'dew point')} = $value;
			}
		}
		$rows->[$j]{main::key($num++,0,2,'pressure')} = $pressure;
	}
	if ($extra > 1){
		if ($weather->{'heat-index'} || (defined $weather->{'heat-index-c'} && 
		defined $weather->{'heat-index-f'})){
			$value = process_unit(
			$weather->{'heat-index'},
			$weather->{'heat-index-c'},'C',
			$weather->{'heat-index-f'},'F');
			$rows->[$j]{main::key($num++,0,2,'heat index')} = $value;
		}
		if ($weather->{'windchill'} || (defined $weather->{'windchill-c'} && 
		defined $weather->{'windchill-f'})){
			$value = process_unit(
			$weather->{'windchill'},
			$weather->{'windchill-c'},'C',
			$weather->{'windchill-f'},'F');
			$rows->[$j]{main::key($num++,0,2,'wind chill')} = $value;
		}
		if ($extra > 2){
			if ($weather->{'forecast'}){
				$j = scalar @$rows;
				push(@$rows, {
				main::key($num++,1,1,'Forecast') => $weather->{'forecast'},
				},);
			}
		}
	}
	$j = scalar @$rows;
	if ($extra > 2 && !$use{'filter'}){
		complete_location(
		$location,
		$weather->{'city'},
		$weather->{'state'},
		$weather->{'country'});
	}
	push(@$rows, {
	main::key($num++,1,1,'Locale') => $location->[1],
	},);
	if ($extra > 2 && !$use{'filter'} && ($weather->{'elevation-m'} || 
	$weather->{'elevation-ft'})){
		$rows->[$j]{main::key($num++,0,2,'altitude')} = process_elevation(
		$weather->{'elevation-m'},
		$weather->{'elevation-ft'});
	}
	$rows->[$j]{main::key($num++,0,2,'current time')} = $weather->{'date-time'},;
	if ($extra > 2){
		$weather->{'observation-time-local'} = 'N/A' if !$weather->{'observation-time-local'};
		$rows->[$j]{main::key($num++,0,2,'observation time')} = $weather->{'observation-time-local'};
		if ($weather->{'sunrise'}){
			$rows->[$j]{main::key($num++,0,2,'sunrise')} = $weather->{'sunrise'};
		}
		if ($weather->{'sunset'}){
			$rows->[$j]{main::key($num++,0,2,'sunset')} = $weather->{'sunset'};
		}
		if ($weather->{'moonphase'}){
			$value = $weather->{'moonphase'} . '%';
			$value .= ($weather->{'moonphase-graphic'}) ? ' ' . $weather->{'moonphase-graphic'} :'';
			$rows->[$j]{main::key($num++,0,2,'moonphase')} = $value;
		}
	}
	if ($weather->{'api-source'}){
		$rows->[$j]{main::key($num++,0,1,'Source')} = $weather->{'api-source'};
	}
	eval $end if $b_log;
}

sub process_elevation {
	eval $start if $b_log;
	my ($meters,$feet) = @_;
	my ($result,$i_unit,$m_unit) = ('','ft','m');
	$feet = sprintf("%.0f", 3.28 * $meters) if defined $meters && !$feet;
	$meters = sprintf("%.1f", $feet/3.28) if defined $feet && !$meters;
	$meters = sprintf("%.0f", $meters) if $meters;
	if (defined $meters  && $weather_unit eq 'mi'){
		$result = "$meters $m_unit ($feet $i_unit)";
	}
	elsif (defined $meters && $weather_unit eq 'im'){
		$result = "$feet $i_unit ($meters $m_unit)";
	}
	elsif (defined $meters && $weather_unit eq 'm'){
		$result = "$meters $m_unit";
	}
	elsif (defined $feet && $weather_unit eq 'i'){
		$result = "$feet $i_unit";
	}
	else {
		$result = 'N/A';
	}
	eval $end if $b_log;
	return $result;
}

sub process_unit {
	eval $start if $b_log;
	my ($primary,$metric,$m_unit,$imperial,$i_unit) = @_;
	my $result = '';
	if (defined $metric && defined $imperial && $weather_unit eq 'mi'){
		$result = "$metric $m_unit ($imperial $i_unit)";
	}
	elsif (defined $metric && defined $imperial && $weather_unit eq 'im'){
		$result = "$imperial $i_unit ($metric $m_unit)";
	}
	elsif (defined $metric && $weather_unit eq 'm'){
		$result = "$metric $m_unit";
	}
	elsif (defined $imperial && $weather_unit eq 'i'){
		$result = "$imperial $i_unit";
	}
	elsif ($primary){
		$result = $primary;
	}
	else {
		$result = 'N/A';
	}
	eval $end if $b_log;
	return $result;
}

sub process_wind {
	eval $start if $b_log;
	my ($primary,$direction,$mph,$ms,$gust_mph,$gust_ms) = @_;
	my ($result,$gust_kmh,$kmh,$i_unit,$m_unit,$km_unit) = ('','','','mph','m/s','km/h');
	# get rid of possible gust values if they are the same as wind values
	$gust_mph = undef if $gust_mph && $mph && $mph eq $gust_mph;
	$gust_ms = undef if $gust_ms && $ms && $ms eq $gust_ms;
	# calculate and round, order matters so that rounding only happens after math done
	$ms = 0.44704 * $mph if defined $mph && !defined $ms;
	$mph = $ms * 2.23694 if defined $ms && !defined $mph;
	$kmh = sprintf("%.0f",  18*$ms/5) if defined $ms;
	$ms = sprintf("%.1f", $ms) if defined $ms; # very low mph speeds yield 0, which is wrong
	$mph = sprintf("%.0f", $mph) if defined $mph;
	$gust_ms = 0.44704 * $gust_mph if $gust_mph && !$gust_ms;
	$gust_kmh = 18 * $gust_ms / 5 if $gust_ms;
	$gust_mph = $gust_ms * 2.23694 if $gust_ms && !$gust_mph;
	$gust_mph = sprintf("%.0f", $gust_mph) if $gust_mph;
	$gust_kmh = sprintf("%.0f", $gust_kmh) if $gust_kmh;
	$gust_ms = sprintf("%.0f", $gust_ms) if  $gust_ms;
	if (!defined $mph && $primary){
		$result = $primary;
	}
	elsif (defined $mph && defined $direction){
		if ($weather_unit eq 'mi'){
			$result = "from $direction at $ms $m_unit ($kmh $km_unit, $mph $i_unit)";
		}
		elsif ($weather_unit eq 'im'){
			$result = "from $direction at $mph $i_unit ($ms $m_unit, $kmh $km_unit)";
		}
		elsif ($weather_unit eq 'm'){
			$result = "from $direction at $ms $m_unit ($kmh $km_unit)";
		}
		elsif ($weather_unit eq 'i'){
			$result = "from $direction at $mph $i_unit";
		}
		if ($gust_mph){
			if ($weather_unit eq 'mi'){
				$result .= ". Gusting to $ms $m_unit ($kmh $km_unit, $mph $i_unit)";
			}
			elsif ($weather_unit eq 'im'){
				$result .= ". Gusting to $mph $i_unit ($ms $m_unit, $kmh $km_unit)";
			}
			elsif ($weather_unit eq 'm'){
				$result .= ". Gusting to $ms $m_unit ($kmh $km_unit)";
			}
			elsif ($weather_unit eq 'i'){
				$result .= ". Gusting to $mph $i_unit";
			}
		}
	}
	elsif ($primary){
		$result = $primary;
	}
	else {
		$result = 'N/A';
	}
	eval $end if $b_log;
	return $result;
}

sub get_weather {
	eval $start if $b_log;
	my ($location) = @_;
	my $now = POSIX::strftime "%Y%m%d%H%M", localtime;
	my ($date_time,$freshness,$tz,$weather_data);
	my $weather = {};
	my $loc_name = lc($location->[0]);
	$loc_name =~ s/-\/|\s|,/-/g;
	$loc_name =~ s/--/-/g;
	my $file_cached = "$user_data_dir/weather-$loc_name-$weather_source.txt";
	if (-r $file_cached){
		@$weather_data = main::reader($file_cached);
		$freshness = (split(/\^\^/, $weather_data->[0]))[1];
		# print "$now:$freshness\n";
	}
	if (!$freshness || $freshness < ($now - 60)){
		$weather_data = download_weather($now,$file_cached,$location);
	}
	# print join("\n", @weather_data), "\n";
	# NOTE: because temps can be 0, we can't do if value tests
	foreach (@$weather_data){
		my @working = split(/\s*\^\^\s*/, $_);
		next if ! defined $working[1] || $working[1] eq '';
		if ($working[0] eq 'api_source'){
			$weather->{'api-source'} = $working[1];
		}
		elsif ($working[0] eq 'city'){
			$weather->{'city'} = $working[1];
		}
		elsif ($working[0] eq 'cloud_cover'){
			$weather->{'cloud-cover'} = $working[1];
		}
		elsif ($working[0] eq 'country'){
			$weather->{'country'} = $working[1];
		}
		elsif ($working[0] eq 'dewpoint_string'){
			$weather->{'dewpoint'} = $working[1];
			$working[1] =~ /^([0-9\.]+)\sF\s\(([0-9\.]+)\sC\)/;
			$weather->{'dewpoint-c'} = $2;;
			$weather->{'dewpoint-f'} = $1;;
		}
		elsif ($working[0] eq 'dewpoint_c'){
			$weather->{'dewpoint-c'} = $working[1];
		}
		elsif ($working[0] eq 'dewpoint_f'){
			$weather->{'dewpoint-f'} = $working[1];
		}
		# WU: there are two elevations, we want the first one
		elsif (!$weather->{'elevation-m'} && $working[0] eq 'elevation'){
			# note: bug in source data uses ft for meters, not 100% of time, but usually
			$weather->{'elevation-m'} = $working[1];
			$weather->{'elevation-m'} =~ s/\s*(ft|m).*$//;
		}
		elsif ($working[0] eq 'error'){
			$weather->{'error'} = $working[1];
		}
		elsif ($working[0] eq 'forecast'){
			$weather->{'forecast'} = $working[1];
		}
		elsif ($working[0] eq 'heat_index_string'){
			$weather->{'heat-index'} = $working[1];
			$working[1] =~ /^([0-9\.]+)\sF\s\(([0-9\.]+)\sC\)/;
			$weather->{'heat-index-c'} = $2;;
			$weather->{'heat-index-f'} = $1;
		}
		elsif ($working[0] eq 'heat_index_c'){
			$weather->{'heat-index-c'} = $working[1];
		}
		elsif ($working[0] eq 'heat_index_f'){
			$weather->{'heat-index-f'} = $working[1];
		}
		elsif ($working[0] eq 'relative_humidity'){
			$working[1] =~ s/%$//;
			$weather->{'humidity'} = $working[1];
		}
		elsif ($working[0] eq 'local_time'){
			$weather->{'local-time'} = $working[1];
		}
		elsif ($working[0] eq 'local_epoch'){
			$weather->{'local-epoch'} = $working[1];
		}
		elsif ($working[0] eq 'moonphase'){
			$weather->{'moonphase'} = $working[1];
		}
		elsif ($working[0] eq 'moonphase_graphic'){
			$weather->{'moonphase-graphic'} = $working[1];
		}
		elsif ($working[0] eq 'observation_time_rfc822'){
			$weather->{'observation-time-rfc822'} = $working[1];
		}
		elsif ($working[0] eq 'observation_epoch'){
			$weather->{'observation-epoch'} = $working[1];
		}
		elsif ($working[0] eq 'observation_time'){
			$weather->{'observation-time-local'} = $working[1];
			$weather->{'observation-time-local'} =~ s/Last Updated on //;
		}
		elsif ($working[0] eq 'precip_mm'){
			$weather->{'precip-1h-mm'} = $working[1];
		}
		elsif ($working[0] eq 'precip_in'){
			$weather->{'precip-1h-in'} = $working[1];
		}
		elsif ($working[0] eq 'pressure_string'){
			$weather->{'pressure'} = $working[1];
		}
		elsif ($working[0] eq 'pressure_mb'){
			$weather->{'pressure-mb'} = $working[1];
		}
		elsif ($working[0] eq 'pressure_in'){
			$weather->{'pressure-in'} = $working[1];
		}
		elsif ($working[0] eq 'rain_1h_mm'){
			$weather->{'rain-1h-mm'} = $working[1];
		}
		elsif ($working[0] eq 'rain_1h_in'){
			$weather->{'rain-1h-in'} = $working[1];
		}
		elsif ($working[0] eq 'snow_1h_mm'){
			$weather->{'snow-1h-mm'} = $working[1];
		}
		elsif ($working[0] eq 'snow_1h_in'){
			$weather->{'snow-1h-in'} = $working[1];
		}
		elsif ($working[0] eq 'state_name'){
			$weather->{'state'} = $working[1];
		}
		elsif ($working[0] eq 'sunrise'){
			if ($working[1]){
				if ($working[1] !~ /^[0-9]+$/){
					$weather->{'sunrise'} = $working[1];
				}
				# trying to figure out remote time from UTC is too hard
				elsif (!$show{'weather-location'}){
					$weather->{'sunrise'} = POSIX::strftime "%T", localtime($working[1]);
				}
			}
		}
		elsif ($working[0] eq 'sunset'){
			if ($working[1]){
				if ($working[1] !~ /^[0-9]+$/){
					$weather->{'sunset'} = $working[1];
				}
				# trying to figure out remote time from UTC is too hard
				elsif (!$show{'weather-location'}){
					$weather->{'sunset'} = POSIX::strftime "%T", localtime($working[1]);
				}
			}
		}
		elsif ($working[0] eq 'temperature_string'){
			$weather->{'temp'} = $working[1];
			$working[1] =~ /^([0-9\.]+)\sF\s\(([0-9\.]+)\sC\)/;
			$weather->{'temp-c'} = $2;;
			$weather->{'temp-f'} = $1;
			#	$weather->{'temp'} =~ s/\sF/\xB0 F/; # B0
			#	$weather->{'temp'} =~ s/\sF/\x{2109}/;
			#	$weather->{'temp'} =~ s/\sC/\x{2103}/;
		}
		elsif ($working[0] eq 'temp_f'){
			$weather->{'temp-f'} = $working[1];
		}
		elsif ($working[0] eq 'temp_c'){
			$weather->{'temp-c'} = $working[1];
		}
		elsif ($working[0] eq 'timezone'){
			$weather->{'timezone'} = $working[1];
		}
		elsif ($working[0] eq 'visibility'){
			$weather->{'visibility'} = $working[1];
		}
		elsif ($working[0] eq 'visibility_km'){
			$weather->{'visibility-km'} = $working[1];
		}
		elsif ($working[0] eq 'visibility_mi'){
			$weather->{'visibility-mi'} = $working[1];
		}
		elsif ($working[0] eq 'weather'){
			$weather->{'weather'} = $working[1];
		}
		elsif ($working[0] eq 'wind_degrees'){
			$weather->{'wind-degrees'} = $working[1];
		}
		elsif ($working[0] eq 'wind_dir'){
			$weather->{'wind-direction'} = $working[1];
		}
		elsif ($working[0] eq 'wind_mph'){
			$weather->{'wind-mph'} = $working[1];
		}
		elsif ($working[0] eq 'wind_gust_mph'){
			$weather->{'wind-gust-mph'} = $working[1];
		}
		elsif ($working[0] eq 'wind_gust_ms'){
			$weather->{'wind-gust-ms'} = $working[1];
		}
		elsif ($working[0] eq 'wind_ms'){
			$weather->{'wind-ms'} = $working[1];
		}
		elsif ($working[0] eq 'wind_string'){
			$weather->{'wind'} = $working[1];
		}
		elsif ($working[0] eq 'windchill_string'){
			$weather->{'windchill'} = $working[1];
			$working[1] =~ /^([0-9\.]+)\sF\s\(([0-9\.]+)\sC\)/;
			$weather->{'windchill-c'} = $2;
			$weather->{'windchill-f'} = $1;
		}
		elsif ($working[0] eq 'windchill_c'){
			$weather->{'windchill-c'} = $working[1];
		}
		elsif ($working[0] eq 'windchill_f'){
			$weather->{'windchill_f'} = $working[1];
		}
	}
	if ($show{'weather-location'}){
		if ($weather->{'observation-time-local'} && 
		 $weather->{'observation-time-local'} =~ /^(.*)\s([a-z_]+\/[a-z_]+)$/i){
			$tz = $2;
		}
		if (!$tz && $weather->{'timezone'}){
			$tz = $weather->{'timezone'};
			$weather->{'observation-time-local'} .= ' (' . $weather->{'timezone'} . ')' if $weather->{'observation-time-local'};
		}
		# very clever trick, just make the system think it's in the 
		# remote timezone for this local block only
		local $ENV{'TZ'} = $tz if $tz; 
		$date_time = POSIX::strftime "%c", localtime();
		$date_time = test_locale_date($date_time,'','');
		$weather->{'date-time'} = $date_time;
		# only wu has rfc822 value, and we want the original observation time then
		if ($weather->{'observation-epoch'} && $tz){
			$date_time = POSIX::strftime "%Y-%m-%d %T ($tz %z)", localtime($weather->{'observation-epoch'});
			$date_time = test_locale_date($date_time,$show{'weather-location'},$weather->{'observation-epoch'});
			$weather->{'observation-time-local'} = $date_time;
		}
	}
	else {
		$date_time = POSIX::strftime "%c", localtime();
		$date_time = test_locale_date($date_time,'','');
		$tz = ($location->[2]) ? " ($location->[2])" : ''; 
		$weather->{'date-time'} = $date_time . $tz;
	}
	# we get the wrong time using epoch for remote -W location
	if (!$show{'weather-location'} && $weather->{'observation-epoch'}){
		$date_time = POSIX::strftime "%c", localtime($weather->{'observation-epoch'});
		$date_time = test_locale_date($date_time,$show{'weather-location'},$weather->{'observation-epoch'});
		$weather->{'observation-time-local'} = $date_time;
	}
	eval $end if $b_log;
	return $weather;
}

sub download_weather {
	eval $start if $b_log;
	my ($now,$file_cached,$location) = @_;
	my ($temp,$ua,$url);
	my $weather = [];
	$url = "https://smxi.org/opt/xr2.php?loc=$location->[0]&src=$weather_source";
	$ua = 'weather';
	if ($fake{'weather'}){
		# my $file2 = "$fake_data_dir/weather/weather-1.xml";
		# my $file2 = "$fake_data_dir/weather/feed-oslo-1.xml";
		# local $/;
		# my $file = "$fake_data_dir/weather/weather-1.xml";
		# open(my $fh, '<', $file) or die "can't open $file: $!";
		# $temp = <$fh>;
	}
	else {
		$temp = main::download_file('stdout',$url,'',$ua);
	}
	@$weather = split('\n', $temp) if $temp;
	unshift(@$weather, "timestamp^^$now");
	main::writer($file_cached,$weather);
	# print "$file_cached: download/cleaned\n";
	eval $end if $b_log;
	return $weather;
}

# Rsolve wide character issue, if detected, switch to iso 
# date format, we won't try to be too clever here.
sub test_locale_date {
	my ($date_time,$location,$epoch) = @_;
	# $date_time .= 'дек';
	# print "1: $date_time\n";
	if ($date_time =~ m/[^\x00-\x7f]/){
		if (!$location && $epoch){
			$date_time = POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime($epoch);
		}
		else {
			$date_time = POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime();
		}
	}
	$date_time =~ s/\s+$//;
	# print "2: $date_time\n";
	return $date_time;
}

## Location Data ##
sub location_data {
	eval $start if $b_log;
	my $location = $_[0];
	if ($show{'weather-location'}){
		my $location_string;
		$location_string = $show{'weather-location'};
		$location_string =~ s/\+/ /g;
		if ($location_string =~ /,/){
			my @temp = split(',', $location_string);
			my $sep = '';
			my $string = '';
			foreach (@temp){
				$_ = ucfirst($_);
				$string .= $sep . $_;
				$sep = ', ';
			}
			$location_string = $string;
		}
		$location_string = main::filter($location_string);
		@$location = ($show{'weather-location'},$location_string,'');
	}
	else {
		get_location($location);
	}
	eval $end if $b_log;
}

sub get_location {
	eval $start if $b_log;
	my $location = $_[0];
	my ($city,$country,$freshness,%loc,$loc_arg,$loc_string,@loc_data,$state);
	my $now = POSIX::strftime "%Y%m%d%H%M", localtime;
	my $file_cached = "$user_data_dir/location-main.txt";
	if (-r $file_cached){
		@loc_data = main::reader($file_cached);
		$freshness = (split(/\^\^/, $loc_data[0]))[1];
	}
	if (!$freshness || $freshness < $now - 90){
		my $temp;
		my $url = "http://geoip.ubuntu.com/lookup";
		#	{
		#		local $/;
		#		my $file = "$fake_data_dir/weather/location-1.xml";
		#		open(my $fh, '<', $file) or die "can't open $file: $!";
		#		$temp = <$fh>;
		#	}
		$temp  = main::download_file('stdout',$url);
		@loc_data = split('\n', $temp);
		@loc_data = map {
		s/<\?.*<Response>//;
		s/<\/[^>]+>/\n/g;
		s/>/^^/g;
		s/<//g;
		$_;
		} @loc_data;
		@loc_data = split('\n', $loc_data[0]);
		unshift(@loc_data, "timestamp^^$now");
		main::writer($file_cached,\@loc_data);
		# print "$file_cached: download/cleaned\n";
	}
	foreach (@loc_data){
		my @working = split(/\s*\^\^\s*/, $_);
		# print "$working[0]:$working[1]\n";
		if ($working[0] eq 'CountryCode3'){
			$loc{'country3'} = $working[1];
		}
		elsif ($working[0] eq 'CountryCode'){
			$loc{'country'} = $working[1];
		}
		elsif ($working[0] eq 'CountryName'){
			$loc{'country2'} = $working[1];
		}
		elsif ($working[0] eq 'RegionCode'){
			$loc{'region-id'} = $working[1];
		}
		elsif ($working[0] eq 'RegionName'){
			$loc{'region'} = $working[1];
		}
		elsif ($working[0] eq 'City'){
			$loc{'city'} = $working[1];
		}
		elsif ($working[0] eq 'ZipPostalCode'){
			$loc{'zip'} = $working[1];
		}
		elsif ($working[0] eq 'Latitude'){
			$loc{'lat'} = $working[1];
		}
		elsif ($working[0] eq 'Longitude'){
			$loc{'long'} = $working[1];
		}
		elsif ($working[0] eq 'TimeZone'){
			$loc{'tz'} = $working[1];
		}
	}
	# print Data::Dumper::Dumper \%loc;
	# assign location, cascade from most accurate
	# latitude,longitude first
	if ($loc{'lat'} && $loc{'long'}){
		$loc_arg = "$loc{'lat'},$loc{'long'}";
	}
	# city,state next
	elsif ($loc{'city'} && $loc{'region-id'}){
		$loc_arg = "$loc{'city'},$loc{'region-id'}";
	}
	# postal code last, that can be a very large region
	elsif ($loc{'zip'}){
		$loc_arg = $loc{'zip'};
	}
	$country = ($loc{'country3'}) ? $loc{'country3'} : $loc{'country'};
	$city = ($loc{'city'}) ? $loc{'city'} : 'City N/A';
	$state = ($loc{'region-id'}) ? $loc{'region-id'} : 'Region N/A';
	$loc_string = main::filter("$city, $state, $country");
	@$location = ($loc_arg,$loc_string,$loc{'tz'});
	# print ($loc_arg,"\n", join("\n", @loc_data), "\n",scalar @loc_data, "\n");
	eval $end if $b_log;
}

sub complete_location {
	eval $start if $b_log;
	my ($location,$city,$state,$country) = @_;
	if ($location->[1] && $location->[1] =~ /[0-9+-]/ && $city){
		$location->[1] = $country . ', ' . $location->[1] if $country && $location->[1] !~ m|$country|i;
		$location->[1] = $state . ', ' . $location->[1] if $state && $location->[1] !~ m|$state|i;
		$location->[1] = $city . ', ' . $location->[1] if $city && $location->[1] !~ m|$city|i;
	}
	eval $end if $b_log;
}
}

#### -------------------------------------------------------------------
#### ITEM UTILITIES
#### -------------------------------------------------------------------

# android only, for distro / OS id and machine data
sub set_build_prop {
	eval $start if $b_log;
	my $path = '/system/build.prop';
	$loaded{'build-prop'} = 1;
	return if ! -r $path;
	my @data = reader($path,'strip');
	foreach (@data){
		my @working = split('=', $_);
		next if $working[0] !~ /^ro\.(build|product)/;
		if ($working[0] eq 'ro.build.date.utc'){
			$build_prop{'build-date'} = strftime "%F", gmtime($working[1]);
		}
		# ldgacy, replaced by ro.product.device
		elsif ($working[0] eq 'ro.build.product'){
			$build_prop{'build-product'} = $working[1];
		}
		# this can be brand, company, android, it varies, but we don't want android value
		elsif ($working[0] eq 'ro.build.user'){
			$build_prop{'build-user'} = $working[1] if $working[1] !~ /android/i;
		}
		elsif ($working[0] eq 'ro.build.version.release'){
			$build_prop{'build-version'} = $working[1];
		}
		elsif ($working[0] eq 'ro.product.board'){
			$build_prop{'product-board'} = $working[1];
		}
		elsif ($working[0] eq 'ro.product.brand'){
			$build_prop{'product-brand'} = $working[1];
		}
		elsif ($working[0] eq 'ro.product.device'){
			$build_prop{'product-device'} = $working[1];
		}
		elsif ($working[0] eq 'ro.product.manufacturer'){
			$build_prop{'product-manufacturer'} = $working[1];
		}
		elsif ($working[0] eq 'ro.product.model'){
			$build_prop{'product-model'} = $working[1];
		}
		elsif ($working[0] eq 'ro.product.name'){
			$build_prop{'product-name'} = $working[1];
		}
		elsif ($working[0] eq 'ro.product.screensize'){
			$build_prop{'product-screensize'} = $working[1];
		}
	}
	log_data('dump','%build_prop',\%build_prop) if $b_log;
	print Dumper \%build_prop if $dbg[20];
	eval $end if $b_log;
}

# Return all detected compiler versions
# args: 0: compiler
sub get_compiler_data {
	eval $start if $b_log;
	my $compiler = $_[0];
	my $compiler_version;
	my $compilers = [];
	# NOTE: see %program_values for regex used for different gcc syntax
	if (my $program = check_program($compiler)){
		(my $name,$compiler_version) = ProgramData::full($compiler,$program);
	}
	if ($extra > 1){
		# glob /usr/bin,/usr/local/bin for ccs, strip out all non numeric values
		if (my @temp = globber("/usr/{local/,}bin/${compiler}{-,}[0-9]*")){
			# usually: gcc-11, sometimes: gcc-11.2.0, gcc-2.8, gcc48 [FreeBSD]
			foreach (@temp){
				if (/\/${compiler}-?(\d+\.\d+|\d+)(\.\d+)?/){
					# freebsd uses /usr/local/bin/gcc48, gcc34 for old gccs. Why?
					my $working = ($bsd_type && $1 >= 30) ? $1/10 : $1;
					if (!$compiler_version || $compiler_version !~ /^$working\b/){
						push(@$compilers, $working);
					}
				}
			}
			@$compilers = sort {$a <=> $b} @$compilers if @$compilers;
		}
	}
	unshift(@$compilers, $compiler_version) if $compiler_version;
	log_data('dump','@$compilers',$compilers) if $b_log;
	print "$compiler\n", Data::Dumper::Dumper $compilers if $dbg[62];
	eval $end if $b_log;
	return $compilers;
}

sub set_dboot_data {
	eval $start if $b_log;
	$loaded{'dboot'} = 1;
	my ($file,@db_data,@dm_data,@temp);
	my ($counter) = (0);
	if (!$fake{'dboot'}){
		$file = $system_files{'dmesg-boot'};
	}
	else {
		# $file = "$fake_data_dir/bsd/dmesg-boot/bsd-disks-diabolus.txt";
		# $file = "$fake_data_dir/bsd/dmesg-boot/freebsd-disks-solestar.txt";
		# $file = "$fake_data_dir/bsd/dmesg-boot/freebsd-enceladus-1.txt";
		## matches: toshiba: openbsd-5.6-sysctl-2.txt
		# $file = "$fake_data_dir/bsd/dmesg-boot/openbsd-5.6-dmesg.boot-1.txt";
		## matches: compaq: openbsd-5.6-sysctl-1.txt"
		# $file = "$fake_data_dir/bsd/dmesg-boot/openbsd-dmesg.boot-1.txt";
		# $file = "$fake_data_dir/bsd/dmesg-boot/openbsd-6.8-battery-sensors-1.txt";
	}
	if ($file){
		return if ! -r $file;
		@db_data = reader($file);
		# sometimes > 1 sessions stored, dump old ones
		for (@db_data){
			if (/^(Dragonfly|OpenBSD|NetBSD|FreeBSD is a registered trademark|Copyright.*Midnight)/){
				$counter++;
				undef @temp if $counter > 1; 
			}
			push(@temp,$_);
		}
		@db_data = @temp;
		undef @temp; 
		my @dm_data = grabber('dmesg 2>/dev/null');
		# clear out for netbsd, only 1 space following or lines won't match
		@dm_data = map {$_ =~ s/^\[[^\]]+\]\s//;$_} @dm_data;
		$counter = 0;
		# dump previous sessions, and also everything roughly before dmesg.boot 
		# ends, it does't need to be perfect, we just only want the actual post 
		# boot data
		for (@dm_data){
			if (/^(Dragonfly|OpenBSD|NetBSD|FreeBSD is a registered trademark|Copyright.*Midnight)/ ||
				/^(smbus[0-9]:|Security policy loaded|root on)/){
				$counter++;
				undef @temp if $counter > 1; 
			}
			push(@temp,$_);
		}
		@dm_data = @temp;
		undef @temp; 
		push(@db_data,'~~~~~',@dm_data);
		# uniq(\@db_data); # get rid of duplicate lines
		# some dmesg repeats, so we need to dump the second and > iterations
		# replace all indented items with ~ so we can id them easily while
		# processing note that if user, may get error of read permissions
		# for some weird reason, real mem and avail mem are use a '=' separator, 
		# who knows why, the others are ':'
		foreach (@db_data){
			$_ =~ s/\s*=\s*|:\s*/:/;
			$_ =~ s/\"//g;
			$_ =~ s/^\s+/~/;
			$_ =~ s/\s\s/ /g;
			$_ =~ s/^(\S+)\sat\s/$1:at /; # ada0 at ahcich0
			push(@{$dboot{'main'}}, $_);
			if ($use{'bsd-battery'} && /^acpi(bat|cmb)/){
				push(@{$sysctl{'battery'}}, $_);
			}
			# ~Debug Features 0:<2 CTX BKPTs,4 Watchpoints,6 Breakpoints,PMUv3,Debugv8>
			elsif ($use{'bsd-cpu'} && 
			 (!/^~(Debug|Memory)/ && /(^cpu[0-9]+:|Features|^~*Origin:\s*)/)){
				push(@{$dboot{'cpu'}}, $_);
			}
			# FreeBSD: 'da*' is a USB device 'ada*' is a SATA device 'mmcsd*' is an SD card
			# OpenBSD: 'sd' is usb device, 'wd' normal drive. OpenBSD uses sd for nvme drives
			# but also has the nvme data: 
			# nvme1 at pci6 dev 0 function 0 vendor "Phison", unknown product 0x5012 rev 0x01: msix, NVMe 1.3
			# nvme1: OWC Aura P12 1.0TB, firmware ECFM22.6, serial 2003100010208
			# scsibus2 at nvme1: 2 targets, initiator 0
			# sd1 at scsibus2 targ 1 lun 0: <NVMe, OWC Aura P12 1.0, ECFM>
			# sd1: 915715MB, 4096 bytes/sector, 234423126 sectors
			elsif ($use{'bsd-disk'} && 
			 /^(ad|ada|da|mmcblk|mmcsd|nvme([0-9]+n)?|sd|wd)[0-9]+(:|\sat\s|.*?\sdetached$)/){
				$_ =~ s/^\(//;
				push (@{$dboot{'disk'}},$_);
			}
			if ($use{'bsd-machine'} && /^bios[0-9]:(at|vendor)/){
				push(@{$sysctl{'machine'}}, $_);
			}
			elsif ($use{'bsd-machine'} && !$dboot{'machine-vm'} && 
			 /(\bhvm\b|innotek|\bkvm\b|microsoft.*virtual machine|openbsd[\s-]vmm|qemu|qumranet|vbox|virtio|virtualbox|vmware)/i){
				push(@{$dboot{'machine-vm'}}, $_);
			}
			elsif ($use{'bsd-optical'} && /^(cd)[0-9]+(\([^)]+\))?(:|\sat\s)/){
				push(@{$dboot{'optical'}},$_);
			}
			elsif ($use{'bsd-pci'} && /^(pci[0-9]+:at|\S+:at pci)/){
				push(@{$dboot{'pci'}},$_);
			}
			elsif ($use{'bsd-ram'} && /(^spdmem)/){
				push(@{$dboot{'ram'}}, $_);
			}
		}
		log_data('dump','$dboot{main}',$dboot{'main'}) if $b_log;
		print Dumper $dboot{'main'} if $dbg[11];
		
		if ($dboot{'main'} && $b_log){
			log_data('dump','$dboot{cpu}',$dboot{'cpu'});
			log_data('dump','$dboot{disk}',$dboot{'disk'});
			log_data('dump','$dboot{machine-vm}',$dboot{'machine-vm'});
			log_data('dump','$dboot{optical}',$dboot{'optical'});
			log_data('dump','$dboot{ram}',$dboot{'ram'});
			log_data('dump','$dboot{usb}',$dboot{'usb'});
			log_data('dump','$sysctl{battery}',$sysctl{'battery'});
			log_data('dump','$sysctl{machine}',$sysctl{'machine'});
		}
		if ($dboot{'main'} && $dbg[11]){
			print("cpu:\n", Dumper $dboot{'cpu'});
			print("disk:\n", Dumper $dboot{'disk'});
			print("machine vm:\n", Dumper $dboot{'machine-vm'});
			print("optical:\n", Dumper $dboot{'optical'});
			print("ram:\n", Dumper $dboot{'ram'});
			print("usb:\n", Dumper $dboot{'usb'});
			print("sys battery:\n", Dumper $sysctl{'battery'});
			print("sys machine:\n", Dumper $sysctl{'machine'});
		}
		# this should help get rid of dmesg usb mounts not present
		# note if you take out one, put in another, it will always show the first 
		# one, I think. Not great. Not using this means all drives attached
		# current session are shown, using it, possibly wrong drive shown, which is bad
		# not using this for now: && (my @disks = grep {/^hw\.disknames/} @{$dboot{'disk'}}
		if ($dboot{'disk'}){
			# hw.disknames:sd0:,sd1:3242432,sd2:
			#$disks[0] =~ s/(^hw\.disknames:|:[^,]*)//g; 
			#@disks = split(',',$disks[0]) if $disks[0];
			my ($id,$value,%dboot_disks,@disks_live,@temp);
			# first, since openbsd has this, let's use it
			foreach (@{$dboot{'disk'}}){
				if (!@disks_live && /^hw\.disknames/){
					$_ =~ s/(^hw\.disknames:|:[^,]*)//g; 
					@disks_live = split(/[,\s]/,$_) if $_;
				}
				else {
					push(@temp,$_);
				}
			}
			@{$dboot{'disk'}} = @temp if @temp;
			foreach my $row (@temp){
				$row =~ /^([^:\s]+)[:\s]+(.+)/;
				$id = $1;
				$value = $2;
				push(@{$dboot_disks{$id}},$value);
				# get rid of detached or non present drives
				if ((@disks_live && !(grep {$id =~ /^$_/} @disks_live)) || 
				 $value =~ /\b(destroyed|detached)$/){
					delete $dboot_disks{$id};
				}
			}
			$dboot{'disk'} = \%dboot_disks;
			log_data('dump','post: $dboot{disk}',$dboot{'disk'}) if $b_log;
			print("post: disk:\n",Dumper $dboot{'disk'}) if $dbg[11];
		}
		if ($use{'bsd-pci'} && $dboot{'pci'}){
			my $bus_id = 0;
			foreach (@{$dboot{'pci'}}){
				if (/^pci[0-9]+:at.*?bus\s([0-9]+)/){
					$bus_id = $1;
					next;
				}
				elsif (/:at pci[0-9]+\sdev/){
					$_ =~ s/^(\S+):at.*?dev\s([0-9]+)\sfunction\s([0-9]+)\s/$bus_id:$2:$3:$1:/;
					push(@temp,$_);
				}
			}
			$dboot{'pci'} = [@temp];
			log_data('dump','$dboot{pci}',$dboot{'pci'}) if $b_log;
			print("pci:\n",Dumper $dboot{'pci'}) if $dbg[11];
		}
	}
	eval $end if $b_log;
}

## DesktopData
# returns array:
# 0: desktop name
# 1: version
# 2: toolkit
# 3: toolkit version
# 4: de/wm components: panels, docks, menus, etc
# 5: wm
# 6: wm version
# 7: tools: screensavers/lockers: running
# 8: tools: screensavers/lockers: all not running, installed
# 9: de advanced data type [eg. kde frameworks]
# 10: de advanced data version
{