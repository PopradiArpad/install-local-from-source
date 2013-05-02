install-local-from-source
=========================

Script to install the newest sources local without disturbing the distribution environment.
It uses auto-apt to install automatically the dependent packages.
It should work on all apt based distributions.

This script doesnt automatize completely the installation of the dependent libs and dev packages but most of them.

Workflow on Ubuntu:
1. Try install-local-from-source.rb install_from_newest
2. If it fails (auto-apt is not perfect, it doesnt catch all needed and installable dependencies)
   first try to install the needed development headers from Synaptic.
   If that version is too old then try to install the newest development package with install-local-from-source.rb install_from_newest
   After that go back to step 1 with your original source.
   
   

