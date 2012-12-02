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
		ini_set ('include_path', '.' . PATH_SEPARATOR . ini_get ('include_path'));	// Ensure current directory is in the include_path
		require_once ('.config.php');
		
		# Ensure an e-mail address is defined
		if (!isSet ($emailAddress)) {
			echo 'No e-mail address was defined.';
		}
		$this->emailAddress = $emailAddress;
		
		# Ensure that the settings have been defined
		if (!isSet ($smsProviderApiKey))	{$this->email ('$smsProviderApiKey is not defined');}
		if (!isSet ($smsNumber))			{$this->email ('$smsNumber is not not defined');}
		if (!isSet ($cyclestreetsApiKey))	{$this->email ('$cyclestreetsApiKey is not not defined');}
		$this->smsProviderApiKey	= $smsProviderApiKey;
		$this->smsNumber			= str_replace (array (' ', '+'), '', $smsNumber);
		$this->cyclestreetsApiKey	= $cyclestreetsApiKey;
		
		# Set the timeout for URL requests
		ini_set ('default_socket_timeout', $this->timeoutSeconds);
		
		# Get the registered checks in this classa
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
					$this->reportProblem ($errorMessage, $result);
					return false;
				}
			}
		}
		
		// No return value
		
	}
	
	
	# Function to report a problem
	private function reportProblem ($errorMessage, $result)
	{
		# Echo (debugging)
		if ($this->debugging) {
			echo $errorMessage;
		}
		
		# Prepend the date
		$date = date ('H:i,j/M');
		$errorMessage = $date . ': ' . $errorMessage;
		
		# Send e-mail
		$this->email ($errorMessage, $result);
		
		# Send SMS
		$this->sendSms ($errorMessage);
	}
	
	
	# E-mail wrapper function
	private function email ($errorMessage, $result = false)
	{
		# Compile the message
		$message = $errorMessage;
		if ($result) {
			$message .= "\n\nThe HTTP response body was:\n" . print_r ($result, true);
		}
		
		# Send e-mail
		mail ($this->emailAddress, '*** CycleStreets automated checks - problem ***', $message, 'From: ' . $this->emailAddress);
	}
	
	
	# SMS sending wrapper function
	private function sendSms ($errorMessage)
	{
		# End if not enabled
		if (!$this->enableSms) {return;}
		if (!strlen ($this->smsNumber)) {return;}
		
		# Send the message
		$url = "https://api.clockworksms.com/http/send.aspx?key={$this->smsProviderApiKey}&to={$this->smsNumber}&content=" . urlencode ($errorMessage);
		file_get_contents ($url);
	}
	
	
	/* Tests */
	
	
	# Route-planning test
	private function test_journey_new (&$errorMessage = false, &$result = false)
	{
		# Plan a route (the split is to avoid bots traversing a repository)
		$routeUrl = "http://www.cyclestreets.net" . "/api/journey.json?key={$this->cyclestreetsApiKey}&plan=quietest&itinerarypoints=-0.140085,51.502022,Buckingham+Palace|-0.129204,51.504353,Horse+Guards+Parade|-0.129394,51.499496,Westminster+Abbey";
		if (!$json = file_get_contents ($routeUrl)) {
			$errorMessage = "The /api/journey call (new journey) did not respond within {$this->timeoutSeconds} seconds.";
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
			|| ($result['waypoint'][0]['@attributes']['longitude'] != '-0.140085')
			
			# Testing..
			// || !isSet ($result['doesnotexist'])
		) {
			$errorMessage = "The /api/journey call (new journey) did not return the expected format.";
			return false;
		}
		
		# Return success
		return true;
	}
	
	
	# Route-retrieval test
	private function test_journey_existing (&$errorMessage = false, &$result = false)
	{
		# Plan a route (the split is to avoid bots traversing a repository)
		$routeUrl = "http://www.cyclestreets.net" . "/api/journey.json?key={$this->cyclestreetsApiKey}&plan=fastest&itinerary=345529";
		if (!$json = file_get_contents ($routeUrl)) {
			$errorMessage = "The /api/journey call (retrieve journey) did not respond within {$this->timeoutSeconds} seconds.";
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
			$errorMessage = "The /api/journey call (retrieve journey) did not return the expected format.";
			return false;
		}
		
		# Return success
		return true;
	}
	
	
	# Nearestpoint test
	private function test_nearestpoint (&$errorMessage = false, &$result = false)
	{
		# Plan a route (the split is to avoid bots traversing a repository)
		$routeUrl = "http://www.cyclestreets.net" . "/api/nearestpoint.json?key={$this->cyclestreetsApiKey}&longitude=0.117950&latitude=52.205302";
		if (!$json = file_get_contents ($routeUrl)) {
			$errorMessage = "The /api/nearestpoint call did not respond within {$this->timeoutSeconds} seconds.";
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
			$errorMessage = "The /api/nearestpoint call did not return the expected format.";
			return false;
		}
		
		# Return success
		return true;
	}
	
	
	# Geocoder test
	private function test_geocoder (&$errorMessage = false, &$result = false)
	{
		# Plan a route (the split is to avoid bots traversing a repository)
		$routeUrl = "http://www.cyclestreets.net" . "/api/geocoder.json?key={$this->cyclestreetsApiKey}&w=0.113937&s=52.201937&e=0.121963&n=52.208669&zoom=16&street=thoday%20street";
		if (!$json = file_get_contents ($routeUrl)) {
			$errorMessage = "The /api/geocoder call did not respond within {$this->timeoutSeconds} seconds.";
			return false;
		}
		
		# Decode the JSON
		$result = json_decode ($json, true);
		// print_r ($result);
		// file_put_contents ('./results.txt', print_r ($result, 1));
		
		# Ensure the data is as expected
		if (
			# Check the marker structure has the first marker
			   !isSet ($result['query'])
			|| !isSet ($result['results'])
			|| !isSet ($result['results']['result'])
			|| !isSet ($result['results']['result']['name'])
			
			# Check for a co-ordinate in the right area of the country
			|| (!substr_count ($result['results']['result']['name'], 'Thoday'))
			|| (!substr_count ($result['results']['result']['longitude'], '0.14'))
			|| (!substr_count ($result['results']['result']['latitude'], '52.20'))
			
			# Testing..
			// || !isSet ($result['doesnotexist'])
		) {
			$errorMessage = "The /api/geocoder call did not return the expected format.";
			return false;
		}
		
		# Return success
		return true;
	}
	
	
	# Photo (retrieval) test
	private function test_photo (&$errorMessage = false, &$result = false)
	{
		# Plan a route (the split is to avoid bots traversing a repository)
		$routeUrl = "http://www.cyclestreets.net" . "/api/photo.json?key={$this->cyclestreetsApiKey}&id=80";
		if (!$json = file_get_contents ($routeUrl)) {
			$errorMessage = "The /api/photo call did not respond within {$this->timeoutSeconds} seconds.";
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
			$errorMessage = "The /api/photo call did not return the expected format.";
			return false;
		}
		
		# Return success
		return true;
	}
	
	
}

?>