# Base class for working with Subversion
class Svn < BrpmAutomation
  
  # Initializes an instance of the class
  #
  # ==== Attributes
  #
  # * +svn+ - path to the svn executable
  # * +options+ - hash of options includes:
  #   url - url for svn repository
  #   base_path - path for the local repository
  #   username - repository user username
  #   password - repository user password
  #   verbose - true for verbose output (default = false)
  #   rebase - starting path for checkouts
  #   simulate - simulate command - echo it (default = false)
  #   output_file - file for logging results
  #
  def initialize(svn, options)
    @url = required_option(options,"url")
    @base_path = required_option(options,"base_path")
    user = get_option(options,"username")
    password = get_option(options,"password")
    @verbose = get_option(options,"verbose", false)
    @rebase = get_option(options, "rebase")
    @rebase =  @url.split("/")[-1] if @rebase == ""
    @simulate = get_option(options,"simulate", false)
    if user != "" && password != ""
      @credential = " --username #{user} --password #{password}"
    else
      @credential = ""
    end
    super(get_option(options,"output_file", nil))
    @svn = svn
  end

  # Performs an svn checkout
  #
  # ==== Attributes
  #
  # * +init+ - true to initilize the checkout and local repo
  # ==== Returns
  #
  # * command output
  def checkout(init = false)
    FileUtils.cd(@base_path, :verbose => true)
    if init
      cmd = "#{@svn} checkout #{@url} #{@rebase}  #{@credential} --non-interactive"
    else
      cmd = "#{@svn} checkout --non-interactive"
    end
    process_cmd(cmd)
  end

  # Performs an svn checkout
  #
  # ==== Returns
  #
  # * command output
  def get
    cmd = "#{@svn} checkout --non-interactive"
    process_cmd(cmd)
  end
  
  # Performs an svn commit
  #
  # ==== Attributes
  #
  # * +message+ - commit string
  # ==== Returns
  #
  # * command output
  def commit(message = "Automation pushed changes")
    # /usr/bin/svn commit . -m "PSENG-0000 Adding PSENG files"
    cmd = "#{@svn} commit . -m \"#{message}\""
    process_cmd(cmd)
  end
  
  # Performs an svn tag
  #
  # ==== Attributes
  #
  # * +source_path+ - path in repo to tag
  # * +tag_name+ - name for tag
  # * +message+ - message to add to tag
  #
  # ==== Returns
  #
  # * command output
  def tag(source_path, tag_name, message)
    ipos = @url.index("trunk")
    raise "Cannot locate trunk path" if ipos.nil?
    tag_path = @url[0..ipos] + "tags/" + tag_name
    cmd = "#{@svn} copy #{source_path} #{tag_path} -m \"#{message}\""
    process_cmd(cmd)
  end
  
  # Performs an svn status
  #
  # ==== Returns
  #
  # * command output
  def status
    process_cmd("#{@svn} status")
  end
  
  # Adds any new files in the local repo to the svn commit list
  #
  # ==== Attributes
  #
  # * +exclude_regex+ - regex to filter add files (file !=~ filter)
  #
  # ==== Returns
  #
  # * command output
  def add_files(options = {})
    result = status
    msg = ""
    exclude = get_option(options,"exclude_regex")
    result.split("\n").each do |item|
      if item.start_with?("?")
        file = item.gsub("?","").strip
        cmd = "#{@svn} add #{file}"
        if exclude == ""
          msg += process_cmd(cmd)
        else
          msg += process_cmd(cmd) if file =~ /#{exclude}/
        end
        res = `#{cmd}`
      end
    end
    "#{result}\n#{msg}"
  end
  
  private        
  
  def process_cmd(cmd)
    goto_base
    res = run_shell(cmd) unless @simulate
    log cmd if @verbose || @simulate
    @simulate ? "ok" : display_result(res)
  end
  
  def goto_base
    @pwd = FileUtils.pwd
    goto_path = @rebase != "" ? File.join(@base_path,@rebase) : @base_path
    FileUtils.cd(goto_path, :verbose => true) if @verbose
    FileUtils.cd(goto_path) unless @verbose
  end

  def svn_errors?(output)
    svn_terms = ["403 Forbidden", "SSL error code", "moorrreee"]
    found = output.scan(/#{svn_terms.join("|")}/)
    found.size > 0
  end

end

# Base class for working with Git
class Git < BrpmAutomation
  
  # Initializes an instance of the class
  #
  # ==== Attributes
  #
  # * +git+ - path to the git executable
  # * +options+ - hash of options includes:
  #   url - url for svn repository
  #   base_path - path for the local repository
  #   username - repository user username
  #   password - repository user password
  #   verbose - true for verbose output
  #   repository - name of remote git repository (default = origin)
  #   artifact_path - path in repository for artifacts (default = .)
  #   branch - scm branch (default = master)
  #   simulate - simulate command - echo it (default = false)
  #   output_file - file for logging results (default = step output file)
  #
  def initialize(git, options)
    @url = get_option(options,"url")
    @base_path = get_option(options,"base_path")
    user = get_option(options,"username")
    password = get_option(options,"password")
    @verbose = get_option(options,"verbose", false)
    @artifact_path = get_option(options,"artifact_path")
    @simulate = get_option(options,"simulate", false)
    update_repo_info(options)
    if user != "" && password != ""
      @credential = " --username #{user} --password #{password}"
    else
      @credential = ""
    end
    super(get_option(options,"output_file", SS_output_file))
    @git = git
  end

  # Updates repository info from options
  #
  # ==== Attributes
  #
  # * +options+ - hash of options, keys [repository, branch]
  # ==== Returns
  #
  # * command output
  def update_repo_info(options)
    @repo = get_option(options,"repository","origin")
    @branch = get_option(options,"branch","master")
  end

  # Performs a GIT checkout or initialize repository
  #
  # ==== Attributes
  #
  # * +init+ - true to initilize the checkout and local repo
  # * +options+ - hash of options, keys [repository, branch, revision, tag]
  # ==== Returns
  #
  # * command output
  def checkout(init = false, options = {})
    update_repo_info(options)
    if init
      cmd = "#{@git} clone #{@url} #{@credential}"
      process_cmd(cmd)
      cmd = "#{@git} checkout #{@branch}"
    else
      revision = get_option(options,"revision")
      tag = get_option(options,"tag")
      if revision != ""
        cmd = "#{@git} checkout #{revision}"
      elsif tag != ""
        cmd = "#{@git} checkout tags/#{tag}"
      else
        cmd = "#{@git} pull #{@repo} #{@branch}"
      end
    end
    process_cmd(cmd)
  end
  
  # Performs an GIT commit
  #
  # ==== Attributes
  #
  # * +message+ - commit string
  # * +options+ - hash of options, keys [repository, branch, push_to_repository]
  # ==== Returns
  #
  # * command output
  def commit(message = "Automation pushed changes", options = {})
    update_repo_info(options)
    push_to_repo = get_option(options,"push_to_repository", true)
    cmd = "#{@git} commit -a -m \"#{message}\""
    result = process_cmd(cmd)
    cmd = "#{@git} push #{repo} #{branch}" if push_to_repo
    result += process_cmd if push_to_repo
    result
  end
  
  # Performs an git tag
  #
  # ==== Attributes
  #
  # * +tag_name+ - name for tag
  # * +message+ - message to add to tag
  # * +options+ - hash of options, keys [repository, branch, push_to_repository, tag_path]
  #
  # ==== Returns
  #
  # * command output
  def tag(tag_name, message, options = {})
    update_repo_info(options)
    tag_path = get_option(options,"push_to_repository", true)
    push_to_repo = get_option(options,"tag_path")
    cmd = "#{@git} tag -a #{tag_path} -m \"#{message}\""
    result = process_cmd(cmd)
    cmd = "#{@git} push #{repo} #{branch}" if push_to_repo
    result += process_cmd if push_to_repo
    result
  end
  
  # Performs an svn statud
  #
  # ==== Returns
  #
  # * command output
  def status
    process_cmd "#{@git} status"
  end
  
  # Adds any new files in the local repo to the git commit list
  #  note: you need to commit after adding files
  #
  # ==== Attributes
  #
  # * +exclude_regex+ - regex to filter add files (file !=~ filter)
  #
  # ==== Returns
  #
  # * command output
  def add_files(exclude_regex = "")
    result = status
    lines = result.split("\n")
    ipos = lines.index("Untracked files:")
    unless ipos.nil?
      files = lines[(ipos + 2)..-3]
      files.each do |item|
        unless File.basename.start_with?(".")
          cmd = "#{@git} add #{item}"
          if exclude == ""
            result += process_cmd(cmd)
          else
            result += process_cmd(cmd)  unless file =~ /#{exclude}/
          end      
        end
      end
    end
    result += status   
    result
  end
  
  private        
  
  def process_cmd(cmd)
    goto_base
    res = run_shell(cmd) unless @simulate
    log cmd if @verbose || @simulate
    @simulate ? "ok" : display_result(res)
  end
  
  def goto_base
    @pwd = FileUtils.pwd
    goto_path = @base_path
    FileUtils.cd(goto_path, :verbose => true) if @verbose
    FileUtils.cd(goto_path) unless @verbose
  end

  def git_errors?(output)
    svn_terms = ["403 Forbidden", "SSL error code", "moorrreee"]
    found = output.scan(/#{svn_terms.join("|")}/)
    found.size > 0
  end

end

