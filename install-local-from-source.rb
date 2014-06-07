#!/usr/bin/ruby
#Script to install the newest sources local without disturbing the distribution environment.
#It uses auto-apt to install automatically the dependent packages.
#
#Contact: popradi.arpad11@gmail.com
#License: GPLv3

require 'net/ftp'
require 'date'
require 'fileutils'

class Settings
  #THIS MUST BE FILLED BY YOU!
  #The root of the locally installed bins/libs etc.
  #E.g /home/yourhome/installed
  def Settings.installation_root
    ""
  end #installation_root
  
  #THIS MUST BE FILLED BY YOU!
  #The root of the locally downloaded and unpacked sources to install.
  #E.g /home/yourhome/source
  def Settings.source_root
    ""
  end #source_root
  
  def Settings.user
    `whoami`.strip
  end #user
  
  def Settings.group
    `groups`.split[0]
  end #group
  
  def Settings.number_of_cores
    `cat /proc/cpuinfo | grep processor | wc -l`.to_i
  end #number_of_cores
end #Settings


module TerminalUser
  def puts_ok(text)
    puts text.align_to_right.green
  end #puts_ok

  def puts_error(text)
    puts text.align_to_right.red
  end #puts_error

  def puts_and_run(message, cmd)
    puts_ok message
    
    if not sh(cmd)
      puts_error "Can not #{message}"
      exit
    end
  end #puts_and_run

  def sh(cmd)
    puts cmd.align_to_right.pink
    
    IO.popen("#{cmd}") do |io|
      while l = io.gets
        puts l
      end
    end 
    
    return $?.success?
  end #sh
end #TerminalUser


class InstallLocalFromSource

  include TerminalUser
  
  def workup_commands()
    command = $*[0]
    
    case command
      when "setup"                      then setup
      when "list_versions"              then list_versions
      when "download_extract"           then download_extract
      when "configure_build_install"    then configure_build_install
      else                                   print_help
    end
  end #workup_commands
    
  private
  
  def print_help
    puts_ok <<-END
    Script to help install the sources local without disturbing the distribution environment.
    It uses auto-apt to install automatically the dependent packages.
    Auto-apt tries to install the missing packages from the distribution repositories.
    
    To use the installed bins and libs You must use the environment variables
    PATH, LD_LIBRARY_PATH and PKG_CONFIG_PATH in your development environment.

    PATH            is to find installed binaries.
    LD_LIBRARY_PATH is to find the installed libs.
    PKG_CONFIG_PATH is to be able to compile agains the installed headers and libs.
    
    Usage:
    ------
    
    install-local-from-source.rb command parameters
    
    To get help to a command that needs parameter type the command without parameter.
    
    Commands:
    ---------
        
    setup                      It setups the download, install and usage environment.
    list_versions              It lists the available versions. 
    download_extract           It downloads and extracts a version.
    configure_build_install    It configures builds and installs an already downloaded version.
    END
  end #print_help

  def setup
    Setup.new.do_setup
  end #setup
  
  def list_versions
    ListVersions.new.workup_commands
  end #list_versions
  
  def download_extract
    DownloadExtract.new.workup_commands
  end #download_extract
  
  def configure_build_install
    ConfigureBuildInstall.new.workup_commands
  end #configure_build_install
end #InstallLocalFromSource



class Setup

  include TerminalUser
  
  def done?
    [settings_setup_done?, dir_setup_done?, bashrc_setup_done?, auto_apt_setup_done?].all?
  end #done?
  
  def do_setup
    setup_settings
    setup_dir
    setup_bashrc
    setup_auto_apt
  end #do_setup
  
  private
  
  def settings_setup_done?
    [not(Settings.installation_root.empty?), not(Settings.source_root.empty?)].all?
  end #settings_setup_done?
  
  def dir_setup_done?
    [Settings.installation_root, Settings.source_root].map{|d| File.directory?(d)}.all?
  end #dir_setup_done?
  
  def bashrc_setup_done?
    [path_variable_has_value?("PATH",             "#{Settings.installation_root}/bin"),
     path_variable_has_value?("LD_LIBRARY_PATH",  "#{Settings.installation_root}/lib"),
     path_variable_has_value?("PKG_CONFIG_PATH",  "#{Settings.installation_root}/lib/pkgconfig")].all?
  end #bashrc_setup_done?
  
  def auto_apt_setup_done?
    auto_apt_installed?
    #I can not check, whether auto-apt is setuped too...
  end #auto_apt_setup_done?

  def setup_settings
    if not settings_setup_done?
      puts_error "You must edit the Settings class in #{__FILE__}."
      exit
    end
    
    puts_ok "Installation root and source root are defined."
    puts_ok "  Installation root is #{Settings.installation_root}"
    puts_ok "  Source root is       #{Settings.source_root}"
  end #setup_settings
  
  def setup_dir
    make_dir_if_not_exist(Settings.installation_root, "Installation root")
    make_dir_if_not_exist(Settings.source_root,       "Source root")
    
    puts_ok "Installation root and source root directories exist."
  end #setup_dir
  
  def setup_bashrc
    if not bashrc_setup_done?
      puts_ok <<-END
      One or more needed environment variables of PATH, LD_LIBRARY_PATH, PKG_CONFIG_PATH are not set.
      Should I set them in your .bashrc? (yes/no)
      END
      
      exit if STDIN.gets.strip != "yes"
      
      File.open("#{ENV["HOME"]}/.bashrc", 'a') do |f|
          installation_root = Settings.installation_root
          
          variable_settings = <<-END
          #set by install-local-from-source.rb 
          ####################################
          export PATH=#{installation_root}/bin:$PATH
          export LD_LIBRARY_PATH=#{installation_root}/lib:$LD_LIBRARY_PATH
          export PKG_CONFIG_PATH=#{installation_root}/lib/pkgconfig:$PKG_CONFIG_PATH

          END
          
          f <<  variable_settings.align_to_right()
      end
      puts_ok "Your .bashrc is modified. The simplest way to use these modifications if You open a new terminal and run this script from that again."
      exit
    end
    
    puts_ok "PATH, LD_LIBRARY_PATH, PKG_CONFIG_PATH are set right."
  end #setup_bashrc
  
  def setup_auto_apt
    if not auto_apt_installed?
      puts_and_run("Installing auto-apt. You must type Y if You want to install (The question \"Do You want to continue [Y/n])\" is not seen.",
                  "sudo apt-get install auto-apt")
    else              
      puts_ok <<-END
      Auto-apt is installed.
      I can not check, whether it's setuped.
      If it's not setuped, the needed packages that could be installed from your distribution repositories
      automatically can not be installed automatically.
      END
    end
    
    puts_ok "Should I update the auto-apt database now? (yes/no) It can take a half an hour."
    exit if STDIN.gets.strip != "yes"
    
    puts_and_run("auto-apt: Retrieve new lists of Contents (available file list.) It can take some time..",
                "sudo auto-apt update")
    
    puts_and_run("auto-apt: Regenerate lists of Contents (available file list, no download).It can take some time..",
                "sudo auto-apt updatedb")
    
    puts_and_run("auto-apt: Generate installed file lists.It can take some time..",
                "sudo auto-apt update-local")
    
    puts "Auto-apt is installed and setuped.".green
  end #setup_auto_apt
  
  def make_dir_if_not_exist(dirpath, purpose)
    if not File.directory?(dirpath)
      puts_and_run("No #{purpose} directory. Creating it.",
                   "mkdir -p #{dirpath}")
    end
  end #check_and_setup_environment
  
  def path_variable_has_value?(variable, expected_part)
    ENV[variable] and ENV[variable].split(':').include?(expected_part)
  end #path_variable_has_value?
  
  def auto_apt_installed?
    `which auto-apt`
    $?.success?
  end #auto_apt_installed?
end #Setup


class  NeedsSetup

  include TerminalUser
  
  def initialize
    if not Setup.new.done?
      puts_error "Setup is needed. Do install-local-from-source.rb setup" 
      exit
    end
  end #initialize
end

  
class ListVersions < NeedsSetup

  def workup_commands
    host = $*[1]
    dir  = $*[2]
    
    if not [host,dir].all?
      print_help
      exit
    end
    
    tar_files = Repository.new(host, dir).tar_files
    
    puts tar_files.sort_by {|v| v.creation_date}
    puts_ok "Files are sorted by creation date. The stable version is not known."
  end #workup_commands
  
  private

  def print_help
    puts_ok <<-END
    install-local-from-source.rb list_versions host dir
    
    Example
    -------
    install-local-from-source.rb list_versions "ftp.gnome.org" "/pub/GNOME/sources/clutter"
    END
  end #print_help
  
end #ListVersions


class DownloadExtract < NeedsSetup

  def workup_commands
    tarfile = $*[1]
    host    = $*[2]
    dir     = $*[3]
    
    if not [tarfile,host,dir].all?
      print_help
      exit
    end
    
    install_dir = "#{Settings.source_root}/#{TarFile.project_version(tarfile)}"
    if File.exist?(install_dir)
      puts_ok "#{install_dir} already exists. Do you want to replace it with a new download? (yes/no)"
      if STDIN.gets.strip != "yes"
        puts_ok "Nothing happened."
        exit
      end
    end
    Repository.new(host, dir).download(tarfile)
    
    puts_and_run("Extracting #{tarfile}",
                 "cd #{Settings.source_root}; tar -xf #{tarfile}")

    puts_and_run("Removing #{tarfile}",
                 "cd #{Settings.source_root}; rm  #{tarfile}")
  end #workup_commands
  
  private

  def print_help
    puts_ok <<-END
    install-local-from-source.rb download_extract tarfile host dir
    
    Example
    -------
    install-local-from-source.rb download_extract clutter-1.18.2.tar.xz "ftp.gnome.org" "/pub/GNOME/sources/clutter"
    END
  end #print_help
  
end #DownloadExtract


class ConfigureBuildInstall < NeedsSetup

  def workup_commands
    project_version         = $*[1]
    extra_configure_options = $*[2..-1]
    
    working_dir_path =  case project_version
                          when nil
                            print_help
                            exit
                          when "HERE"
                            `pwd`.strip
                          else
                             "#{Settings.source_root}/#{project_version}"
                        end
    
    if not Dir.exist?(working_dir_path)
      puts_error "No dir #{working_dir_path}"
      exit
    end
    
    if extra_configure_options
      extra_configure_options = extra_configure_options.join(' ')
    end

    if not File.exist?("#{working_dir_path}/configure")
      puts_error <<-END
        No #{working_dir_path}/configure!
        Run ./autogen.sh.
        For that libtool, shtool, autogen, {gtk-doc-tools} must be installed.
        END
      exit
    end
    
    configure_build_install(working_dir_path, extra_configure_options)
  end #workup_commands
  
  private

  def print_help
    puts_ok <<-END
    install-local-from-source.rb configure_build_install [HERE|project_version] {extra_configure_options}
    
    If HERE is given the configuration and build happens in the current directory
    else in the #{Settings.source_root}/project_version directory.
    
    Examples
    --------
    install-local-from-source.rb configure_build_install clutter-1.18.2 --enable-introspection=yes
    
    or
    
    cd opensource_fixes/gtk+ 
    install-local-from-source.rb configure_build_install HERE
    END
  end #print_help
  
  def configure_build_install(dir_path, extra_configure_options)
    install_root    = Settings.installation_root
    user            = Settings.user
    group           = Settings.group
    number_of_cores = Settings.number_of_cores
    
    puts_and_run("Configure #{dir_path}",
                 "cd #{dir_path}; sudo PKG_CONFIG_PATH=$PKG_CONFIG_PATH LD_LIBRARY_PATH=$LD_LIBRARY_PATH auto-apt run ./configure --prefix=#{install_root} #{extra_configure_options}")
    
    puts_and_run("Give back the source directory to #{user}:#{group}",
                 "sudo chown -R #{user}:#{group} #{dir_path}")
    
    puts_and_run("Build parallel on all cores",
                 "cd #{dir_path}; make -j #{number_of_cores}")
    
    puts_and_run("Install",
                 "cd #{dir_path}; make install")
  end #configure_build_install
  
end #ConfigureBuildInstall

class TarFile

  attr_reader :dir_name, :name, :creation_date
  
  def initialize(dir_name, ftp_dir_list_line)
    @dir_name = dir_name
    elems     = ftp_dir_list_line.split
    this_year = Date.today.year
    
    entry_name             = elems[8]
    month,day,year_or_time = elems[5..7]
    year                   = if year_or_time.include?(":") then this_year else year_or_time end

    creation_date = Date.parse("#{year}-#{month}-#{day}")
    #"FTP servers that use a UNIX directory structure do not include year information for files modified within the last 6-12 months." Hehe
    if Date.today < creation_date
      year          = Date.today.year - 1
      creation_date = Date.parse("#{year}-#{month}-#{day}")
    end
    
    @name           = entry_name
    @creation_date  = creation_date
  end #initialize
  
  def to_s
    "#{name}\t#{creation_date}"
  end #to_s
  
  def TarFile.project_version(tarfile)
    tarfile[ /(^.*-[\d\.]+)\.tar/, 1 ]
  end #TarFile.project_version
end #TarFile

class Repository

  include TerminalUser
  
  def initialize(host, dir)
    raise "Currently only ftp hosts are supported." if host !~ /^ftp\./
    
    @host = host
    @dir  = dir
  end #initialize

  def tar_files
    versions = []
    
    Net::FTP.open(@host) do |ftp|
      ftp.login
      ftp.chdir(@dir)
      
      entry_count = ftp.ls('*').size
      visited_entries = 0
      ftp.ls('*') do |e1|
        visited_entries = visited_entries+1
        elems1 = e1.split
        
        #only directories are interesting
        entry_rights = elems1[0]
        if entry_rights !~ /^d.*/
          #workaround for an ftp bug: next hangs if this is the last entry and recursive ls was used. Hehe
          if visited_entries == entry_count
            return versions
          else
            next
          end
        end
        
        dir_name = elems1[8]
        puts "visiting #{dir_name}"
        
        ftp.chdir(dir_name)
        ftp.ls('*') do |e2|
          elems2 = e2.split
          
          #only tar files are interesting
          entry_name = elems2[8]
          next if entry_name !~ /\.tar\./
          
          versions << TarFile.new(dir_name, e2)
        end        
        ftp.chdir("..")
      end
    end
    
    puts "tar_files finished"
    versions
   end #tar_files

  def download(tarfile)
    if not version = tarfile[ /([\d\.]+)\.tar\./ , 1]
     puts_error "Can not determine the version number of #{tarfile}"
     exit      
    end
    if not main_version = version[ /\d+\.\d+/ ]
     puts_error "Can not determine the main version number of #{tarfile}"
     exit      
    end
    file_on_ftp   = "#{@dir}/#{main_version}/#{tarfile}"
    download_path = "#{Settings.source_root}/#{tarfile}"
    puts_ok "Downloading #{@host}:#{file_on_ftp} to #{download_path}"
    Net::FTP.open(@host) do |ftp|
      ftp.login
      ftp.getbinaryfile(file_on_ftp, download_path)
    end
    
    download_path
  end #download
   
end #Repository

class String
  # colorization
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end

  def red
    colorize(31)
  end

  def green
    colorize(32)
  end
  
  def pink
    colorize(35)
  end
  
  def align_to_right
    shortest_intendation = 1000
    self.lines.each {|l| if l =~ /^(\s+)\w+/ and $1.length < shortest_intendation  then shortest_intendation = $1.length end}
    shortest_intendation = (shortest_intendation == 1000) ? 0 : shortest_intendation
    self.lines.map {|l| l[shortest_intendation..-1]}.join
  end #align_to_right
end #String


InstallLocalFromSource.new.workup_commands



