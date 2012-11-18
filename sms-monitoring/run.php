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
		
		# Run each test
		foreach ($tests as $test) {
			if (!$this->{$test} ($errorMessage, $result)) {
				$this->reportProblem ($errorMessage, $result);
				return false;
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
	
	
	# Route-planning check
	private function test_journey_new (&$errorMessage = false, &$result = false)
	{
		# Plan a route (the split is to avoid bots traversing a repository)
		$routeUrl = "http://www.cyclestreets.net" . "/api/journey.json?key={$this->cyclestreetsApiKey}&plan=quietest&itinerarypoints=-0.140085,51.502022,Buckingham+Palace|-0.129204,51.504353,Horse+Guards+Parade|-0.129394,51.499496,Westminster+Abbey";
		if (!$json = file_get_contents ($routeUrl)) {
			$errorMessage = "Could not retrieve results of /api/journey call (new journey) within {$this->timeoutSeconds} seconds.";
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
	
	
	# Route-retrieval check
	private function test_journey_existing (&$errorMessage = false, &$result = false)
	{
		# Plan a route (the split is to avoid bots traversing a repository)
		$routeUrl = "http://www.cyclestreets.net" . "/api/journey.json?key={$this->cyclestreetsApiKey}&plan=fastest&itinerary=345529";
		if (!$json = file_get_contents ($routeUrl)) {
			$errorMessage = "Could not retrieve results of /api/journey call (retrieve journey) within {$this->timeoutSeconds} seconds.";
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
	
	
}

?>