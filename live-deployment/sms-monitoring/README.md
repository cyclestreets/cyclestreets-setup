# SMS monitoring

This section provides an monitoring facility that will check for a valid
response and message to SMS and e-mail in the event of a problem.

## Installation

	# Ensure dependencies (PHP, and a mail-sending program) installed
	sudo apt-get install php5
	sudo apt-get install exim4

	# Clone the repository
	cd ~
	git clone https://github.com/cyclestreets/cyclestreets-setup.git
	cd cyclestreets-setup/live-deployment/sms-monitoring/
	
	# Copy the template and fill it in
	cp -pr .config.php.template .config.php
	pico -w .config.php
	
	# Add a cron entry, e.g. every 15 minutes; see: http://stackoverflow.com/a/8106460/180733
	command="php ~/cyclestreets-setup/live-deployment/sms-monitoring/run.php"
	job="0,15,30,45 * * * * $command"
	cat <(fgrep -i -v "$command" <(crontab -l)) <(echo "$job") | crontab -