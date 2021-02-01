<?php

# Allow long running
set_time_limit (0);

# End if lockfile present
$lockFile = '/websites/www/content/data/dbmigrate.txt.lock';
if (file_exists ($lockFile)) {return;}

# Create the lockfile to prevent long execution, noting the date for info
file_put_contents ($lockFile, date (DATE_RFC822));

# Get the list of migration files
chdir ('/websites/www/content/db/migrate/');
$files = glob ('*.sql');

# Index by datetime revision, i.e. YYYYMMDDHHMMSS
$migrations = array ();
foreach ($files as $file) {
	if (preg_match ('/^([0-9]{14})_.+\.sql/', $file, $matches)) {
		$revision = $matches[1];
		$migrations[$revision] = $file;
	}
}

# Get the last migration time in the list
$lastKey = key (array_slice ($migrations, -1, 1, true));

# If there is no database state file, create it, and set it to the latest migration, i.e. assume the initial installation is at the latest position
$databaseStateFile = '/websites/www/content/data/dbmigrate.txt';
if (!file_exists ($databaseStateFile)) {
	file_put_contents ($databaseStateFile, $lastKey);
}

# Get the current database structure revision
$currentRevision = (int) file_get_contents ($databaseStateFile);

# Determine the migrations that need to be run
$run = array ();
foreach ($migrations as $revision => $sqlFile) {
	if ($revision > $currentRevision) {
		$run[$revision] = $sqlFile;
	}
}

# End if no migrations to run
if (!$run) {
	unlink ($lockFile);
	return true;
}

# Load the database credentials
$_SERVER['SERVER_NAME'] = 'localhost';
require_once ('/websites/www/content/.config.php');

# Connect to the database
try {
	$databaseConnection = new PDO (
		"mysql:host={$config['hostname']};charset=utf8mb4",		// Database is selected as a query below
		$config['username'],
		$config['password'],
		array (
			PDO::ATTR_ERRMODE, PDO::ERRMODE_SILENT,		// Avoid fatal errors
			PDO::ATTR_EMULATE_PREPARES => 1,			// See: https://stackoverflow.com/a/23258691
			PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;"
		)
	);
} catch (PDOException $e) {
	echo 'Error!: ' . $e->getMessage () . "\n";
	unlink ($lockFile);
	exit (1);		// Linux return value
}

# Define a queries function; see: https://stackoverflow.com/a/23258691
function runQueries ($databaseConnection, $sql)
{
	# If the SQL contains an indication that it should be run manually, skip
	if (substr_count ($sql, '-- manual-installation')) {
		return true;	// Return true, so that the counter advances
	}
	
	# Execute the SQL
	$stmt = $databaseConnection->prepare ($sql);
	$stmt->execute ();
	
	# Check for errors
	$i = 0;
	do {
		$i++;
	} while ($stmt->nextRowset ());
	$error = $stmt->errorInfo ();
	if ($error[0] != '00000') {
		echo "Query {$i} failed: " . $error[2] . "\n";
		return false;
	}
	
	# Return success
	return true;
}

# Execute each SQL file
foreach ($run as $revision => $sqlFile) {
	
	# Load the query/queries file
	$sql = file_get_contents ($sqlFile);
	
	# Prepend use of main database, which the specific query may override; this cannot be done within the DSN as that would fail on non-default database
	$sql = "USE {$config['database']};" . "\n\n" . $sql;
	
	# Run the queries
	if (!runQueries ($databaseConnection, $sql)) {
		unlink ($lockFile);
		exit (1);		// Linux return value
	}
	
	# Update the state file with this revision
	file_put_contents ($databaseStateFile, $revision);
}

# Remove the lockfile
unlink ($lockFile);

# Confirm success
return true;

?>
