<?php

# Run
new doCheck ();

# Program
class doCheck
{
	# Class properties
	private $debugging = false;
	private $enableSms = true;
	private $serverUrlMain = 'http://www.cyclestreets.net';
	private $apiV2UrlMain = 'https://api.cyclestreets.net/v2';
	private $apiVersions = array (
		'http://%s.cyclestreets.net',
		'https://%s.cyclestreets.net/v2'
	);
	private $retryInterval = 20;	// Time to wait before retrying a test

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
		if (!isSet ($timeoutSeconds))		{$this->email ('Setup', '$timeoutSeconds is not defined');}
		if (!isSet ($smsProviderApiKey))	{$this->email ('Setup', '$smsProviderApiKey is not defined');}
		if (!isSet ($smsNumbers))		{$this->email ('Setup', '$smsNumbers is not defined');}
		if (!isSet ($testApiKeys))		{$this->email ('Setup', '$testApiKeys is not defined');}
		
		# Set settings as properties
		$this->timeoutSeconds		= $timeoutSeconds;
		$this->smsProviderApiKey	= $smsProviderApiKey;
		if (is_string ($smsNumbers)) {$smsNumbers = array ($smsNumbers);}
		foreach ($smsNumbers as $index => $smsNumber) {
			$smsNumbers[$index] = str_replace (array (' ', '+'), '', $smsNumber);
		}
		$this->smsNumbers		= $smsNumbers;
		if (isSet ($retryInterval)) {$this->retryInterval = $retryInterval;}

		# Set the timeout for URL requests
		ini_set ('default_socket_timeout', $this->timeoutSeconds);
		
		# Set the user-agent string
		ini_set ('user_agent', 'CycleStreets API monitor');
		
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

		// Apply the test to each of the apiKeys
		// $testSpec is false to skip all tests, true to apply all test, or an array of only those tests to apply
		// !! Note the tests abandon at the first failure so later tests are not tried - risking masking of other problems.
		foreach ($testApiKeys as $testApiKey => $testSpec) {

			// Skip tests for this apiKey if required
			if (!$testSpec) {continue;}

			// Bind
			$this->testApiKey = $testApiKey;

			# Use the standard API URLs by default for this key
			$this->serverUrl	= $this->serverUrlMain;
			$this->apiV2Url		= $this->apiV2UrlMain;
			
			# When key-specific API URLs are defined for this key
			if (isSet ($keySpecificApiUrls[$testApiKey])) {

				// Test with each URL (for both V1 and V2)
				foreach ($keySpecificApiUrls[$testApiKey] as $url) {

					$this->serverUrl	= $url;
					$this->apiV2Url		= $url;

					// Run the tests
					if (!$this->runtests ($tests, $testSpec)) {return;}
				}
				// Done this apiKey
				continue;
			}

			// Run the tests
			if (!$this->runtests ($tests, $testSpec)) {return;}
		}

		// No return value
	}

	/**
	 * Run each test; if it fails, wait a short while then try again before reporting a problem
	 * @return bool
	 */
	private function runtests ($tests, $testSpec)
	{
		foreach ($tests as $test) {

			// Skip tests not specified for this api key
			if (is_array ($testSpec) && !in_array ($test, $testSpec)) {continue;}

			// Reset the test result
			$result = false;

			// Run the test
			if ($this->{$test} ($errorMessage, $result)) {continue;}

			// Retry
			if ($this->retryInterval) {

				// Test failed: wait before retrying
				sleep ($this->retryInterval);

				// Reset the test result
				$result = false;

				// Retry
				if ($this->{$test} ($errorMessage, $result)) {continue;}
			}

			// Report
			$this->reportProblem ($test, $errorMessage, $result);

			// Abandon
			return false;
		}

		// All passed
		return true;
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

		# Echo when email not available
		if (!$this->emailAddress) {
			echo "*** CycleStreets problem with {$test} ***\n";
			echo $message . "\n";
			return;
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
		$apiUrl = $this->serverUrl . "/api/journey.json?key={$this->testApiKey}&plan=quietest&itinerarypoints=-0.14009,51.50202,Buckingham+Palace|-0.12920,51.50435,Horse+Guards+Parade|-0.12939,51.49950,Westminster+Abbey";
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
			
			# Check for a valid waypoint - check to four decimal places of lon/lat (about 100 metres) as nodes can move a bit
			|| !isSet ($result['waypoint'])
			|| !isSet ($result['waypoint'][0])
			|| !isSet ($result['waypoint'][0]['@attributes'])
			|| !isSet ($result['waypoint'][0]['@attributes']['longitude'])
			|| (!substr_count ($result['waypoint'][0]['@attributes']['longitude'], '-0.1400'))
			|| !isSet ($result['waypoint'][0]['@attributes']['latitude'])
			|| (!substr_count ($result['waypoint'][0]['@attributes']['latitude'], '51.5020'))
			
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
	private function xxxtedddst_journey_existing (&$errorMessage = false, &$result = false)
	{
		# Plan a route (the split is to avoid bots traversing a repository)
		$apiUrl = $this->serverUrl . "/api/journey.json?key={$this->testApiKey}&plan=fastest&itinerary=345529";
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
		# Obtain a photo (the split is to avoid bots traversing a repository)
		$apiUrl = $this->apiV2Url . "/nearestpoint?key={$this->testApiKey}&lonlat=0.117950,52.205302";
		if (!$json = @file_get_contents ($apiUrl)) {
			$errorMessage = "The /v2/nearestpoint call did not respond within {$this->timeoutSeconds} seconds. URL: {$apiUrl}";
			return false;
		}
		
		# Decode the JSON
		$result = json_decode ($json, true);
		// print_r ($result);
		// file_put_contents ('./results.txt', print_r ($result, 1));
		
		# Ensure the data is as expected
		if (
			# Check the marker structure has the first marker
			   !isSet ($result['features'])
			|| !isSet ($result['features'][0])
			|| !isSet ($result['features'][0]['geometry'])
			|| !isSet ($result['features'][0]['geometry']['coordinates'])
			|| !isSet ($result['features'][0]['geometry']['coordinates'][0])
			|| !isSet ($result['features'][0]['geometry']['coordinates'][1])
			
			# Check for a co-ordinate in the right area of the country
			|| (!substr_count ($result['features'][0]['geometry']['coordinates'][0], '0.11'))
			|| (!substr_count ($result['features'][0]['geometry']['coordinates'][1], '52.2'))
			
			# Testing..
			// || !isSet ($result['doesnotexist'])
		) {
			$errorMessage = "The /v2/nearestpoint call did not return the expected format. URL: {$apiUrl}";
			return false;
		}
		
		# Return success
		return true;
	}
	
	
	# Geocoder test
	private function test_geocoder (&$errorMessage = false, &$result = false)
	{
		# Plan a route (the split is to avoid bots traversing a repository)
		$apiUrl = $this->serverUrl . "/api/geocoder.json?key={$this->testApiKey}&w=0.113937&s=52.201937&e=0.121963&n=52.208669&zoom=16&street=thoday%20street";
		if (!$json = @file_get_contents ($apiUrl)) {
			$errorMessage = "The /api/geocoder call did not respond within {$this->timeoutSeconds} seconds. URL: {$apiUrl}";
			return false;
		}
		
		# Decode the JSON
		$result = json_decode ($json, true);
		// print_r ($result);
		// file_put_contents ('./results.txt', print_r ($result, 1));

		 // Initialise this flag
		 $testFailed = false;

		# Ensure the data is as expected
		if (
			# Check the marker structure
			   !isSet ($result['query'])
			|| !isSet ($result['results'])
			|| !isSet ($result['results']['result'])) {

			// Test will fail
			$testFailed = true;

		} else {

			# When there is more then one result for Thoday Street check the first
			$thodayResult = (isset ($result['results']['result']['name']) ? $result['results']['result'] : $result['results']['result'][0]);
		}

		if ($testFailed
			|| !isSet ($thodayResult['name'])
			
			# Check for a co-ordinate in the right area of the country
			|| (!substr_count ($thodayResult['name'], 'Thoday'))
			|| abs ($thodayResult['longitude'] - 0.14) > 0.1
			|| abs ($thodayResult['latitude'] - 52.20) > 0.1
			
			# Testing...
		    #|| true
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
		# Obtain a photo (the split is to avoid bots traversing a repository)
		$apiUrl = $this->apiV2Url . "/photomap.location?key={$this->testApiKey}&id=80&fields=id,latitude,longitude,caption&format=flat";
		if (!$json = @file_get_contents ($apiUrl)) {
			$errorMessage = "The /v2/photomap.location call did not respond within {$this->timeoutSeconds} seconds. URL: {$apiUrl}";
			return false;
		}
		
		# Decode the JSON
		$result = json_decode ($json, true);
		// print_r ($result);
		// file_put_contents ('./results.txt', print_r ($result, 1));
		
		# Ensure the data is as expected
		if (
			# Check the data structure
			   !isSet ($result['longitude'])
			|| !isSet ($result['caption'])
			
			# Check for a co-ordinate in the right area of the country and a correct caption
			|| (!substr_count ($result['longitude'], '0.141'))
			|| (!substr_count ($result['caption'], 'York Street'))
			
			# Testing..
			// || !isSet ($result['doesnotexist'])
		) {
			$errorMessage = "The /v2/photomap.location call did not return the expected format. URL: {$apiUrl}";
			return false;
		}
		
		# Return success
		return true;
	}

}
