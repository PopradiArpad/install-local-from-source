#!/usr/bin/ruby
#Script to install the newest sources local without disturbing the distribution environment.
#It uses auto-apt to install automatically the dependent packages.
#
#Contact: popradi.arpad11@gmail.com
#License: GPLv3

require 'net/ftp'
require 'date'
require 'fileutils'

class InstallLocalFromSource
    
    class Config
    
        #THIS MUST BE FILLED BY YOU!
        #The root of the locally installed bins/libs etc.
        #E.g /home/yourhome/installed
        def Config.installation_root()
            ""
        end #installation_root
        
        #THIS MUST BE FILLED BY YOU!
        #The root of the locally downloaded and unpacked sources to install.
        #E.g /home/yourhome/source
        def Config.source_root()
            ""
        end #source_root
        
        def Config.user()
            `whoami`.strip
        end #user
        
        def Config.group()
            `groups`.split[0]
        end #group
        
        def Config.number_of_cores()
            `cat /proc/cpuinfo | grep processor | wc -l`.to_i
        end #number_of_cores
        
        def Config.check
            if not valid?
                puts_and_exit "You must edit the InstallLocalFromSource::Config class in #{__FILE__}.".red
            end
        end #check
        
        def Config.valid?
            not installation_root.empty? and not source_root.empty? and not user.empty? and not group.empty?
        end #valid?
        
    end #Config

    
    def interpret_cmds()
        case ARGV[0]
            when "install_newest_from"
                 install_newest(ARGV[1], ARGV[2])
            when "setup_auto-apt"
                 AutoApt.setup()
            else     
                msg_ok <<-END
                Script to install the newest sources local without disturbing the distribution environment.
                It uses auto-apt to install automatically the dependent packages.
                To configure it You must edit the InstallLocalFromSource::Config class in this file.
                
                To use the installed bins and libs You must use the environment variables
                PATH, LD_LIBRARY_PATH and PKG_CONFIG_PATH in your development environment.
         
                PATH is to find installed binaries.
                LD_LIBRARY_PATH is to find the installed libs.
                PKG_CONFIG_PATH is to be able to compile agains the installed headers and libs.
                
                Commands:
                
                install_newest_from host dir
                    
                    E.g: install-local-from-source.rb install_newest_from "ftp.gnome.org" "/pub/GNOME/sources/clutter"
                    
                         downloads,
                         extracts,
                         configures (with the automatically installation of the needed dependent packages of the distibution)
                         and installes
                         the newest version of the clutter library.
                         
                setup_auto-apt
                    
                    installs (if needed) and setups the auto-apt.
                END
        end
    end #interpret_cmds

    
    private
    

    def install_newest(host, dir)
    
        check_and_setup_environment
        
        downloader = Downloader.new
    
        exit if not downloader.download_newest_and_extract(host, dir)
        
        configure_build_install(downloader.get_unzipped_dir_name)
    end #install_newest

    def check_and_setup_environment
    
        Config::check

        make_dir_if_not_exist(Config::installation_root, "Installation root")
        make_dir_if_not_exist(Config::source_root,       "Source root")
        
        AutoApt::check
        ShellVariables::check
    end #check_and_setup_environment
    
    def make_dir_if_not_exist(dirpath, dirname)
        if not File.directory?(dirpath)
            msg_and_cmd("The #{dirname} doesnt exist. Creating directory.",
                        "mkdir -p #{dirpath}")
        end
    end #check_and_setup_environment
    
    def configure_build_install(dir)
        source_root     = Config::source_root
        install_root    = Config::installation_root
        user            = Config::user
        group           = Config::group
        number_of_cores = Config::number_of_cores
        
        dir_path = "#{source_root}/#{dir}"
    
        msg_and_cmd("Configure #{dir_path}",
                    "cd #{dir_path}; sudo PKG_CONFIG_PATH=$PKG_CONFIG_PATH auto-apt run ./configure --prefix=#{install_root}")
        
        msg_and_cmd("Give back the source directory to #{user}:#{group}",
                    "sudo chown -R #{user}:#{group} #{dir_path}")
        
        msg_and_cmd("Build parallel on all cores",
                    "cd #{dir_path}; make -j #{number_of_cores}")
        
        msg_and_cmd("Install",
                    "cd #{dir_path}; make install")
    end #configure_build_install
    
    class AutoApt
    
        def AutoApt.check()
            if installed?()
                msg_ok <<-END
                auto-apt is installed. I ASSUME it setuped too. If it's not setuped, the needed packages that could be installed
                from your distribution repositories automatically can not be installed automatically. In that case You must call:
                install-local-from-source.rb setup_auto-apt
                END
            else
                AutoApt.setup()
            end
        end #check
        
        def AutoApt.setup()
            if not installed?()
                msg_and_cmd("Installing auto-apt. You must type Y if You want to install (The question \"Do You want to continue [Y/n])\" is not seen.",
                            "sudo apt-get  install auto-apt")
            end
            
            msg_ok "Should I update the auto-apt database now? (yes/no) It can take a half an hour."
            exit if STDIN.gets.strip != "yes"
            
            msg_and_cmd("auto-apt: Retrieve new lists of Contents (available file list.) It can take some time..",
                        "sudo auto-apt update")
            
            
            msg_and_cmd("auto-apt: Regenerate lists of Contents (available file list, no download).It can take some time..",
                        "sudo auto-apt updatedb")
            
            msg_and_cmd("auto-apt: Generate installed file lists.It can take some time..",
                        "sudo auto-apt update-local")

        end #setup
        
        private
        
        def AutoApt.installed?()
            `which auto-apt`
            $?.success?
        end #installed?
        
    end #AutoApt

    class ShellVariables
    
        def ShellVariables.check()
            variables_are_set  = true
            installation_root = Config::installation_root
            
            variables_are_set  &= check_whether_a_path_variable_has_value("PATH",             "#{installation_root}/bin")
            variables_are_set  &= check_whether_a_path_variable_has_value("LD_LIBRARY_PATH",  "#{installation_root}/lib")
            variables_are_set  &= check_whether_a_path_variable_has_value("PKG_CONFIG_PATH",  "#{installation_root}/lib/pkgconfig")
            
            if not variables_are_set
                msg_ok <<-END

                One or more needed environment variables of PATH, LD_LIBRARY_PATH, PKG_CONFIG_PATH are not set.
                Should I set them in your .bashrc? (yes/no)
                END
                
                exit if STDIN.gets.strip != "yes"
                
                ShellVariables.setup()
            end
        end #check()
         
        private
        
        def ShellVariables.setup()
            
            open("#{ENV["HOME"]}/.bashrc", 'a') do |f|
                installation_root = Config::installation_root
                
                variable_settings = <<-END
                #set by install-local-from-source.rb 
                ####################################
                export PATH=#{installation_root}/bin:$PATH
                export LD_LIBRARY_PATH=#{installation_root}/lib:$LD_LIBRARY_PATH
                export PKG_CONFIG_PATH=#{installation_root}/lib/pkgconfig:$PKG_CONFIG_PATH

                END
                
                f <<  variable_settings.align_to_right()
            end

            puts_and_exit "Your .bashrc is modified. The simplest way to use these modifications if You open a new terminal and run this script from that again.".green
        end #setup()
        
        def ShellVariables.check_whether_a_path_variable_has_value(variable, expected_part)
            if not ENV[variable] or not ENV[variable].include?(expected_part)
                msg_error("#{expected_part} is not in #{variable}!")
                return false
            end
            
            true
        end #check_whether_a_path_variable_has_value
            
    end #ShellVariables

    class Downloader

        def get_unzipped_dir_name
             @unzipped_dir_name
        end
        
        def download_newest_and_extract(host, dir)
            source_root = Config::source_root
            
            Net::FTP.open(host) do |ftp|
              ftp.login
              
              ftp.chdir(dir)
              
              #get the newest sub directory
              newest_dir = get_the_newest_directory(ftp)
              
              #change directory into this dir
              ftp.chdir(newest_dir)
              file_datas = ftp.list('*')
              
              #get the newest tar file
              newest_tar_file = get_the_newest_tar_file(ftp)
              msg_ok "The newest version is: #{newest_tar_file}"
              
              @unzipped_dir_name = lib_and_version(newest_tar_file)
              
              unzipped_dir_path = "#{source_root}/#{@unzipped_dir_name}"
              if File.exist?(unzipped_dir_path)
                msg_ok "There is already a #{@unzipped_dir_name} dir in the download directory. Should it be used? (yes/no)"
                if STDIN.gets.strip == "yes"
                    msg_ok "#{@unzipped_dir_name} is not downloaded."
                    return true
                end
                
                msg_and_cmd("Removing #{unzipped_dir_path}",
                            "cd #{source_root}; rm -rf #{@unzipped_dir_name}")
              end
              
              download_path = "#{source_root}/#{newest_tar_file}"
              msg_ok "Downloading #{newest_tar_file} to #{download_path}"
              ftp.getbinaryfile(newest_tar_file, download_path)
              
              msg_and_cmd("Extracting #{newest_tar_file}",
                          "cd #{source_root}; tar -xf #{newest_tar_file}")
              throw "Can not extract #{newest_tar_file}" if not $?.success?
              
              msg_and_cmd("Removing #{newest_tar_file}",
                          "cd #{source_root}; rm  #{newest_tar_file}")
              
              true
            end #Net::FTP.open
        end #download_newest_and_extract
        
        
        private
        
        def lib_and_version(tar_file)
            tar_file.match(/(.*)\.tar\..*/)[1]
        end #lib_and_version
         
        def get_the_newest_directory(ftp)
          #get all directories with theirs creation time
          this_year = Date.today.year
          name_and_creation_date = []
          ftp.list('*').each do |d|
            elems = d.split
            
            #only directories are interesting
            entry_rights = elems[0]
            next if entry_rights !~ /^d.*/
            
            month,day,year_or_time = elems[5..7]
            entry_name = elems[8]
            year = if year_or_time.include?(":") then this_year else year_or_time end

            creation_date = Date.parse("#{year}-#{month}-#{day}")
            name_and_creation_date << {:entry_name => entry_name, :creation_date => creation_date}
          end
          
          throw "No directory entry in #{ftp.pwd}" if name_and_creation_date.empty?
          
          name_of_the_newest(name_and_creation_date)
        end #get_the_newest_directory
        
        def get_the_newest_tar_file(ftp)
          #get all directories with theirs creation time
          this_year = Date.today.year
          name_and_creation_date = []
          ftp.list('*').each do |d|
            elems = d.split
            
            #only tar files are interesting
            entry_name = elems[8]
            next if entry_name !~ /\.tar\./
            
            month,day,year_or_time = elems[5..7]
            year = if year_or_time.include?(":") then this_year else year_or_time end

            creation_date = Date.parse("#{year}-#{month}-#{day}")
            #"FTP servers that use a UNIX directory structure do not include year information for files modified within the last 6-12 months." Hehe
            if Date.today < creation_date
              year = Date.today.year - 1
              creation_date = Date.parse("#{year}-#{month}-#{day}")
            end
            
            name_and_creation_date << {:entry_name => entry_name, :creation_date => creation_date}
          end
          
          throw "No tar file in #{ftp.pwd}" if name_and_creation_date.empty?
          
          name_of_the_newest(name_and_creation_date)
        end #get_the_newest_tar_file
        
        def name_of_the_newest(name_and_creation_date)
            name_and_creation_date.sort_by {|en_cd| en_cd[:creation_date]}[-1][:entry_name]
        end #name_of_the_newest
        
    end #Downloader

end #InstallLocalFromSource

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


def puts_and_exit(text)
    puts text.align_to_right
    exit
end #puts_and_exit

def msg_ok(text)
    puts text.align_to_right.green
end #msg_ok

def msg_error(text)
    puts text.align_to_right.red
end #msg_error

def msg_and_cmd(message, cmd)
    msg_ok(message)
    if not sh(cmd)
        msg_error("Can not #{message}")
        exit
    end
end #msg_and_cmd

def sh(cmd)
    puts cmd.align_to_right.pink
    IO.popen("#{cmd}") do |io|
        while l = io.gets
            puts l
        end
    end 
    
    return $?.success?
end #sh

InstallLocalFromSource.new.interpret_cmds


