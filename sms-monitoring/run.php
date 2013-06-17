<?php

# Run
new doCheck ();

# Program
class doCheck
{
	# Class properties
	private $debugging = false;
	private $timeoutSeconds = 15;
	private $enableSms = true;
	
	
	# Constructor
	public function __construct ()
	{
		# Set the timezone
		ini_set ('date.timezone', 'Europe/London');
		
		# Ensure there is a .config.php file
		require_once (dirname (__FILE__) . '/.config.php');
		
		# Ensure an e-mail address is defined
		if (!isSet ($emailAddress)) {
			echo 'No e-mail address was defined.';
		}
		$this->emailAddress = $emailAddress;
		
		# Ensure that the settings have been defined
		if (!isSet ($smsProviderApiKey))	{$this->email ('Setup', '$smsProviderApiKey is not defined');}
		if (!isSet ($smsNumbers))		{$this->email ('Setup', '$smsNumbers is not defined');}
		if (!isSet ($cyclestreetsApiKey))	{$this->email ('Setup', '$cyclestreetsApiKey is not defined');}
		$this->smsProviderApiKey	= $smsProviderApiKey;
		if (is_string ($smsNumbers)) {$smsNumbers = array ($smsNumbers);}
		foreach ($smsNumbers as $index => $smsNumber) {
			$smsNumbers[$index] = str_replace (array (' ', '+'), '', $smsNumber);
		}
		$this->smsNumbers			= $smsNumbers;
		$this->cyclestreetsApiKey	= $cyclestreetsApiKey;
		
		# Set the timeout for URL requests
		ini_set ('default_socket_timeout', $this->timeoutSeconds);
		
		# Ignore times if required
		if ($ignoreTimes) {
			$currentTime = date ('Hi');
			if (in_array ($currentTime, $ignoreTimes)) {
				return;
			}
		}
		
		# Get the registered checks in this class
		$methods = get_class_methods ($this);
		$tests = array ();
		foreach ($methods as $index => $method) {
			if (preg_match ('/^test_/', $method)) {
				$tests[] = $method;
			}
		}
		
		# Run each test; if it fails, wait a short while then try again before reporting a problem
		foreach ($tests as $test) {
			if (!$this->{$test} ($errorMessage, $result)) {
				// echo "Trying again for {$test}...";
				sleep (20);
				if (!$this->{$test} ($errorMessage, $result)) {
					$this->reportProblem ($test, $errorMessage, $result);
					return false;
				}
			}
		}
		
		// No return value
		
	}
	
	
	# Function to report a problem
	private function reportProblem ($test, $errorMessage, $result)
	{
		# Echo (debugging)
		if ($this->debugging) {
			echo $errorMessage;
		}
		
		# Prepend the date
		$date = date ('H:i,j/M');
		$errorMessage = $date . ': ' . $errorMessage;
		
		# Send e-mail
		$this->email ($test, $errorMessage, $result);
		
		# Send SMS
		$this->sendSms ($errorMessage);
	}
	
	
	# E-mail wrapper function
	private function email ($test, $errorMessage, $result = false)
	{
		# Compile the message
		$message = $errorMessage;
		if ($result) {
			$message .= "\n\nThe HTTP response body was:\n" . print_r ($result, true);
		}
		
		# Send e-mail
		mail ($this->emailAddress, "*** CycleStreets problem with {$test} ***", $message, 'From: ' . $this->emailAddress);
	}
	
	
	# SMS sending wrapper function
	private function sendSms ($errorMessage)
	{
		# End if not enabled
		if (!$this->enableSms) {return;}
		if (!$this->smsNumbers) {return;}

		# Messages should be limited to 140 chars (to avoid being charged multiple times), but as urlencoding is likely to add a few more choose a safer limit
		$limit = 120;

		# Trim if necessary
		if (strlen ($errorMessage) > $limit) {$errorMessage = substr ($errorMessage, 0, $limit);}

		# Encode
		$urlEncodedMessage = urlencode ($errorMessage);

		# Send the message
		foreach ($this->smsNumbers as $smsNumber) {
			$url = "https://api.clockworksms.com/http/send.aspx?key={$this->smsProviderApiKey}&to={$smsNumber}&content=" . $urlEncodedMessage;
			file_get_contents ($url);
		}
	}
	
	
	/* Tests */
	
	
	# Route-planning test
	private function test_journey_new (&$errorMessage = false, &$result = false)
	{
		# Plan a route (the split is to avoid bots traversing a repository)
		$apiUrl = "http://www.cyclestreets.net" . "/api/journey.json?key={$this->cyclestreetsApiKey}&plan=quietest&itinerarypoints=-0.140085,51.502022,Buckingham+Palace|-0.129204,51.504353,Horse+Guards+Parade|-0.129394,51.499496,Westminster+Abbey";
		if (!$json = @file_get_contents ($apiUrl)) {
			$errorMessage = "The /api/journey call (new journey) did not respond within {$this->timeoutSeconds} seconds. URL: {$apiUrl}";
			return false;
		}
		
		# Decode the JSON
		$result = json_decode ($json, true);
		// print_r ($result);
		// file_put_contents ('./results.txt', print_r ($result, 1));
		
		# Ensure the data is as expected
		if (
			# Check the marker structure has the first marker
			   !isSet ($result['marker'])
			|| !isSet ($result['marker'][0])
			|| !isSet ($result['marker'][0]['@attributes'])
			|| !isSet ($result['marker'][0]['@attributes']['start'])
			|| ($result['marker'][0]['@attributes']['start'] != 'Buckingham Palace')
			
			# Check for a co-ordinate in the right area of the country
			|| !isSet ($result['marker'][0]['@attributes']['coordinates'])
			|| (!substr_count ($result['marker'][0]['@attributes']['coordinates'], ' -0.131'))
			
			# Check for a valid waypoint
			|| !isSet ($result['waypoint'])
			|| !isSet ($result['waypoint'][0])
			|| !isSet ($result['waypoint'][0]['@attributes'])
			|| !isSet ($result['waypoint'][0]['@attributes']['longitude'])
			|| ($result['waypoint'][0]['@attributes']['longitude'] != '-0.140059')
			
			# Testing..
			// || !isSet ($result['doesnotexist'])
		) {
			$errorMessage = "The /api/journey call (new journey) did not return the expected format. URL: {$apiUrl}";
			return false;
		}
		
		# Return success
		return true;
	}
	
	
	# Route-retrieval test
	private function test_journey_existing (&$errorMessage = false, &$result = false)
	{
		# Plan a route (the split is to avoid bots traversing a repository)
		$apiUrl = "http://www.cyclestreets.net" . "/api/journey.json?key={$this->cyclestreetsApiKey}&plan=fastest&itinerary=345529";
		if (!$json = @file_get_contents ($apiUrl)) {
			$errorMessage = "The /api/journey call (retrieve journey) did not respond within {$this->timeoutSeconds} seconds. URL: {$apiUrl}";
			return false;
		}
		
		# Decode the JSON
		$result = json_decode ($json, true);
		// print_r ($result);
		// file_put_contents ('./results.txt', print_r ($result, 1));
		
		# Ensure the data is as expected
		if (
			# Check the marker structure has the first marker
			   !isSet ($result['marker'])
			|| !isSet ($result['marker'][0])
			|| !isSet ($result['marker'][0]['@attributes'])
			|| !isSet ($result['marker'][0]['@attributes']['start'])
			|| ($result['marker'][0]['@attributes']['finish'] != 'Thoday Street')
			
			# Check for a co-ordinate in the right area of the country
			|| !isSet ($result['marker'][0]['@attributes']['coordinates'])
			|| (!substr_count ($result['marker'][0]['@attributes']['coordinates'], '0.117867,52.205288 0.117872,52.205441'))
			
			# Check for a valid waypoint
			|| !isSet ($result['waypoint'])
			|| !isSet ($result['waypoint'][0])
			|| !isSet ($result['waypoint'][0]['@attributes'])
			|| !isSet ($result['waypoint'][0]['@attributes']['longitude'])
			|| ($result['waypoint'][0]['@attributes']['longitude'] != '0.117950')
			
			# Testing..
			// || !isSet ($result['doesnotexist'])
		) {
			$errorMessage = "The /api/journey call (retrieve journey) did not return the expected format. URL: {$apiUrl}";
			return false;
		}
		
		# Return success
		return true;
	}
	
	
	# Nearestpoint test
	private function test_nearestpoint (&$errorMessage = false, &$result = false)
	{
		# Plan a route (the split is to avoid bots traversing a repository)
		$apiUrl = "http://www.cyclestreets.net" . "/api/nearestpoint.json?key={$this->cyclestreetsApiKey}&longitude=0.117950&latitude=52.205302";
		if (!$json = @file_get_contents ($apiUrl)) {
			$errorMessage = "The /api/nearestpoint call did not respond within {$this->timeoutSeconds} seconds. URL: {$apiUrl}";
			return false;
		}
		
		# Decode the JSON
		$result = json_decode ($json, true);
		// print_r ($result);
		// file_put_contents ('./results.txt', print_r ($result, 1));
		
		# Ensure the data is as expected
		if (
			# Check the marker structure has the first marker
			   !isSet ($result['marker'])
			|| !isSet ($result['marker']['@attributes'])
			|| !isSet ($result['marker']['@attributes']['longitude'])
			|| !isSet ($result['marker']['@attributes']['latitude'])
			
			# Check for a co-ordinate in the right area of the country
			|| (!substr_count ($result['marker']['@attributes']['longitude'], '0.11'))
			|| (!substr_count ($result['marker']['@attributes']['latitude'], '52.2'))
			
			# Testing..
			// || !isSet ($result['doesnotexist'])
		) {
			$errorMessage = "The /api/nearestpoint call did not return the expected format. URL: {$apiUrl}";
			return false;
		}
		
		# Return success
		return true;
	}
	
	
	# Geocoder test
	private function test_geocoder (&$errorMessage = false, &$result = false)
	{
		# Plan a route (the split is to avoid bots traversing a repository)
		$apiUrl = "http://www.cyclestreets.net" . "/api/geocoder.json?key={$this->cyclestreetsApiKey}&w=0.113937&s=52.201937&e=0.121963&n=52.208669&zoom=16&street=thoday%20street";
		if (!$json = @file_get_contents ($apiUrl)) {
			$errorMessage = "The /api/geocoder call did not respond within {$this->timeoutSeconds} seconds. URL: {$apiUrl}";
			return false;
		}
		
		# Decode the JSON
		$result = json_decode ($json, true);
		// print_r ($result);
		// file_put_contents ('./results.txt', print_r ($result, 1));
		
		# Ensure the data is as expected
		if (
			# Check the marker structure
			   !isSet ($result['query'])
			|| !isSet ($result['results'])
			|| !isSet ($result['results']['result'])

			# When there is more then one result for Thoday Street check the first
			|| $thodayResult = (isset ($result['results']['result']['name']) ? $result['results']['result'] : $result['results']['result'][0])
			|| !isSet ($thodayResult)
			|| !isSet ($thodayResult['name'])
			
			# Check for a co-ordinate in the right area of the country
			|| (!substr_count ($thodayResult['name'], 'Thoday'))
			|| (!substr_count ($thodayResult['longitude'], '0.14'))
			|| (!substr_count ($thodayResult['latitude'], '52.20'))
			
			# Testing..
			// || !isSet ($result['doesnotexist'])
		) {
			$errorMessage = "The /api/geocoder call did not return the expected format. URL: {$apiUrl}";
			return false;
		}
		
		# Return success
		return true;
	}


	# Photo (retrieval) test
	private function test_photo (&$errorMessage = false, &$result = false)
	{
		# Plan a route (the split is to avoid bots traversing a repository)
		$apiUrl = "http://www.cyclestreets.net" . "/api/photo.json?key={$this->cyclestreetsApiKey}&id=80";
		if (!$json = @file_get_contents ($apiUrl)) {
			$errorMessage = "The /api/photo call did not respond within {$this->timeoutSeconds} seconds. URL: {$apiUrl}";
			return false;
		}
		
		# Decode the JSON
		$result = json_decode ($json, true);
		// print_r ($result);
		// file_put_contents ('./results.txt', print_r ($result, 1));
		
		# Ensure the data is as expected
		if (
			# Check the marker structure has the first marker
			   !isSet ($result['request'])
			|| !isSet ($result['result'])
			|| !isSet ($result['result']['longitude'])
			|| !isSet ($result['result']['caption'])
			
			# Check for a co-ordinate in the right area of the country
			|| (!substr_count ($result['result']['longitude'], '0.141'))
			|| (!substr_count ($result['result']['caption'], 'York Street'))
			
			# Testing..
			// || !isSet ($result['doesnotexist'])
		) {
			$errorMessage = "The /api/photo call did not return the expected format. URL: {$apiUrl}";
			return false;
		}
		
		# Return success
		return true;
	}

}