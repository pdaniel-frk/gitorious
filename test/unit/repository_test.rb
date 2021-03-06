# encoding: utf-8
#--
#   Copyright (C) 2009 Nokia Corporation and/or its subsidiary(-ies)
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU Affero General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU Affero General Public License for more details.
#
#   You should have received a copy of the GNU Affero General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#++

require File.dirname(__FILE__) + '/../test_helper'
require "ostruct"

class RepositoryTest < ActiveSupport::TestCase
  
  def new_repos(opts={})
    Repository.new({
      :name => "foo",
      :project => projects(:johans),
      :user => users(:johan),
      :owner => users(:johan)
    }.merge(opts))
  end

  def setup
    @repository = new_repos
    FileUtils.mkdir_p(@repository.full_repository_path, :mode => 0755)
  end
  
  should_validate_presence_of :user_id, :name, :owner_id
  should_validate_uniqueness_of :hashed_path
  should_validate_uniqueness_of :name, :scoped_to => :project_id, :case_sensitive => false
  
  should " only accept names with alphanum characters in it" do
    @repository.name = "foo bar"
    assert !@repository.valid?, 'valid? should be false'
    
    @repository.name = "foo!bar"
    assert !@repository.valid?, 'valid? should be false'
    
    @repository.name = "foobar"
    assert @repository.valid?
    
    @repository.name = "foo42"
    assert @repository.valid?
  end
  
  should "has a unique name within a project" do
    @repository.save
    repos = new_repos(:name => "FOO")
    assert !repos.valid?, 'valid? should be false'
    assert_not_nil repos.errors.on(:name)
    
    assert new_repos(:project => projects(:moes)).valid?
  end
  
  should "cannot have a reserved name" do
    repo = new_repos(:name => Gitorious::Reservations.repository_names.first)
    repo.valid?
    assert_not_nil repo.errors.on(:name)
  end
  
  context "git urls" do  
    setup do
      @host_with_user = "#{GitoriousConfig['gitorious_user']}@#{GitoriousConfig['gitorious_host']}"
      @host = "#{GitoriousConfig['gitorious_host']}"
    end
    
    should "has a gitdir name" do
      assert_equal "#{@repository.project.slug}/foo.git", @repository.gitdir
    end
  
    should "has a push url" do
      assert_equal "#{@host_with_user}:#{@repository.project.slug}/foo.git", @repository.push_url
    end
  
    should "has a clone url" do
      assert_equal "git://#{@host}/#{@repository.project.slug}/foo.git", @repository.clone_url
    end
  
    should "has a http url" do
      assert_equal "http://git.#{@host}/#{@repository.project.slug}/foo.git", @repository.http_clone_url
    end
  
    should "has a clone url with the project name, if it's a mainline" do
      @repository.owner = groups(:team_thunderbird)
      @repository.kind = Repository::KIND_PROJECT_REPO
      assert_equal "git://#{@host}/#{@repository.project.slug}/foo.git", @repository.clone_url
    end
      
    should "have a clone url with the team/user, if it's not a mainline" do
      @repository.kind = Repository::KIND_TEAM_REPO
      url = "git://#{@host}/#{@repository.owner.to_param_with_prefix}/#{@repository.project.slug}/foo.git"
      assert_equal url, @repository.clone_url
      
      @repository.kind = Repository::KIND_USER_REPO
      @repository.owner = users(:johan)
      url = "git://#{@host}/#{users(:johan).to_param_with_prefix}/#{@repository.project.slug}/foo.git"
      assert_equal url, @repository.clone_url
    end
  
    should "has a push url with the project name, if it's a mainline" do
      @repository.owner = groups(:team_thunderbird)
      @repository.kind = Repository::KIND_PROJECT_REPO
      assert_equal "#{@host_with_user}:#{@repository.project.slug}/foo.git", @repository.push_url
    end
      
    should "have a push url with the team/user, if it's not a mainline" do
      @repository.owner = groups(:team_thunderbird)
      @repository.kind = Repository::KIND_TEAM_REPO
      url = "#{@host_with_user}:#{groups(:team_thunderbird).to_param_with_prefix}/#{@repository.project.slug}/foo.git"
      assert_equal url, @repository.push_url
      
      @repository.kind = Repository::KIND_USER_REPO
      @repository.owner = users(:johan)
      url = "#{@host_with_user}:#{users(:johan).to_param_with_prefix}/#{@repository.project.slug}/foo.git"
      assert_equal url, @repository.push_url
    end
  
    should "has a http clone url with the project name, if it's a mainline" do
      @repository.owner = groups(:team_thunderbird)
      @repository.kind = Repository::KIND_PROJECT_REPO
      assert_equal "http://git.#{@host}/#{@repository.project.slug}/foo.git", @repository.http_clone_url
    end
      
    should "have a http clone url with the team/user, if it's not a mainline" do
      @repository.owner = groups(:team_thunderbird)
      @repository.kind = Repository::KIND_TEAM_REPO
      url = "http://git.#{@host}/#{groups(:team_thunderbird).to_param_with_prefix}/#{@repository.project.slug}/foo.git"
      assert_equal url, @repository.http_clone_url
      
      @repository.owner = users(:johan)
      @repository.kind = Repository::KIND_USER_REPO
      url = "http://git.#{@host}/#{users(:johan).to_param_with_prefix}/#{@repository.project.slug}/foo.git"
      assert_equal url, @repository.http_clone_url
    end
  
    should "has a full repository_path" do
      expected_dir = File.expand_path(File.join(GitoriousConfig["repository_base_path"], 
        "#{@repository.full_hashed_path}.git"))
      assert_equal expected_dir, @repository.full_repository_path
    end
  end
  
  should "inits the git repository" do
    path = @repository.full_repository_path
    Repository.git_backend.expects(:create).with(path).returns(true)
    Repository.create_git_repository(@repository.real_gitdir)
    
    assert File.exist?(path), 'File.exist?(path) should be true'
    
    Dir.chdir(path) do
      hooks = File.join(path, "hooks")
      assert File.exist?(hooks), 'File.exist?(hooks) should be true'
      assert File.symlink?(hooks), 'File.symlink?(hooks) should be true'
      assert File.symlink?(File.expand_path(File.readlink(hooks))), 'File.symlink?(File.expand_path(File.readlink(hooks))) should be true'
    end
  end
  
  should "clones a git repository" do
    source = repositories(:johans)
    target = @repository
    target_path = @repository.full_repository_path
    
    git_backend = mock("Git backend")
    Repository.expects(:git_backend).returns(git_backend)
    git_backend.expects(:clone).with(target.full_repository_path, 
      source.full_repository_path).returns(true)
    Repository.expects(:create_hooks).returns(true)
    
    assert Repository.clone_git_repository(target.real_gitdir, source.real_gitdir)
  end

  should "not create hooks if the :skip_hooks option is set to true" do
    source = repositories(:johans)
    target = @repository
    target_path = @repository.full_repository_path
    
    git_backend = mock("Git backend")
    Repository.expects(:git_backend).returns(git_backend)
    git_backend.expects(:clone).with(target.full_repository_path, 
      source.full_repository_path).returns(true)
    Repository.expects(:create_hooks).never
    
    Repository.clone_git_repository(target.real_gitdir, source.real_gitdir, :skip_hooks => true)
  end
  
  should " create the hooks" do
    hooks = "/path/to/hooks"
    path = "/path/to/repository"
    base_path = "#{RAILS_ROOT}/data/hooks"
    
    File.expects(:join).in_sequence.with(GitoriousConfig["repository_base_path"], ".hooks").returns(hooks)
    
    Dir.expects(:chdir).in_sequence.with(path).yields(nil)
    
    File.expects(:symlink?).in_sequence.with(hooks).returns(false)
    File.expects(:exist?).in_sequence.with(hooks).returns(false)
    FileUtils.expects(:ln_s).in_sequence.with(base_path, hooks)
    
    local_hooks = "/path/to/local/hooks"
    File.expects(:join).in_sequence.with(path, "hooks").returns(local_hooks)
    
    File.expects(:exist?).in_sequence.with(local_hooks).returns(true)
    
    File.expects(:join).with(path, "description").in_sequence
    
    File.expects(:open).in_sequence.returns(true)
    
    assert Repository.create_hooks(path)
  end
  
  should "deletes a repository" do
    Repository.git_backend.expects(:delete!).with(@repository.full_repository_path).returns(true)
    Repository.delete_git_repository(@repository.real_gitdir)
  end
  
  should "knows if has commits" do
    @repository.stubs(:new_record?).returns(false)
    @repository.stubs(:ready?).returns(true)
    git_mock = mock("Grit::Git")
    @repository.stubs(:git).returns(git_mock)
    head = mock("head")
    head.stubs(:name).returns("master")
    @repository.git.expects(:heads).returns([head])
    assert @repository.has_commits?, '@repository.has_commits? should be true'
  end
  
  should "knows if has commits, unless its a new record" do
    @repository.stubs(:new_record?).returns(false)
    assert !@repository.has_commits?, '@repository.has_commits? should be false'
  end
  
  should "knows if has commits, unless its not ready" do
    @repository.stubs(:ready?).returns(false)
    assert !@repository.has_commits?, '@repository.has_commits? should be false'
  end
  
  should " build a new repository by cloning another one" do
    repos = Repository.new_by_cloning(@repository)
    assert_equal @repository, repos.parent
    assert_equal @repository.project, repos.project
    assert repos.new_record?, 'new_record? should be true'
  end
  
  should "suggests a decent name for a cloned repository bsed on username" do
    repos = Repository.new_by_cloning(@repository, username="johan")
    assert_equal "johans-clone", repos.name
    repos = Repository.new_by_cloning(@repository, username=nil)
    assert_equal nil, repos.name
  end
  
  should "has it's name as its to_param value" do
    @repository.save
    assert_equal @repository.name, @repository.to_param
  end
  
  should "finds a repository by name or raises" do
    assert_equal repositories(:johans), Repository.find_by_name!(repositories(:johans).name)
    assert_raises(ActiveRecord::RecordNotFound) do
      Repository.find_by_name!("asdasdasd")
    end
  end
  
  context "find_by_path" do
    should "finds a repository by its path" do
      repo = repositories(:johans)
      path = File.join(GitoriousConfig['repository_base_path'], 
                        projects(:johans).slug, "#{repo.name}.git")
      assert_equal repo, Repository.find_by_path(path)
    end
    
    should_eventually "finds a repository by its path, regardless of repository kind" do
      repo = projects(:johans).wiki_repository
      path = File.join(GitoriousConfig['repository_base_path'].chomp("/"), 
                        projects(:johans).slug, "#{repo.name}.git")
      assert_equal repo, Repository.find_by_path(path)
    end
  
    should "finds a group repository by its path" do
      repo = repositories(:johans)
      repo.owner = groups(:team_thunderbird)
      repo.kind = Repository::KIND_TEAM_REPO
      repo.save!
      path = File.join(GitoriousConfig['repository_base_path'], repo.gitdir)
      assert_equal repo, Repository.find_by_path(path)
    end
  
    should "finds a user repository by its path" do
      repo = repositories(:johans)
      repo.owner = users(:johan)
      repo.kind = Repository::KIND_USER_REPO
      repo.save!
      path = File.join(GitoriousConfig['repository_base_path'], repo.gitdir)
      assert_equal repo, Repository.find_by_path(path)
    end
    
    should "scope the find by project id" do
      repo = repositories(:johans)
      repo.owner = groups(:team_thunderbird)
      repo.kind = Repository::KIND_TEAM_REPO
      repo.save!
      same_name_repo = new_repos(:name => repo.name)
      same_name_repo
      same_name_repo.project = projects(:moes)
      same_name_repo.owner = groups(:team_thunderbird)
      same_name_repo.kind = Repository::KIND_TEAM_REPO
      same_name_repo.save!
      path = File.join(GitoriousConfig['repository_base_path'], same_name_repo.gitdir)
      assert_equal same_name_repo, Repository.find_by_path(path)
    end
  end
  
  context "#to_xml" do
    should "xmlilizes git paths as well" do
      assert @repository.to_xml.include?("<clone-url>")
      assert @repository.to_xml.include?("<push-url>")
    end
    
    should "include a description of the kind" do
      assert_match(/<kind>mainline<\/kind>/, @repository.to_xml)
      @repository.kind = Repository::KIND_TEAM_REPO
      assert_match(/<kind>team<\/kind>/, @repository.to_xml)
    end
    
    should "include the project name" do
      assert_match(/<project>#{@repository.project.slug}<\/project>/, @repository.to_xml)
    end
    
    should "include the owner" do
      assert_match(/<owner kind="User">johan<\/owner>/, @repository.to_xml)
    end
  end
  
  context "#writable_by?" do
    should "knows if a user can write to self" do
      @repository.owner = users(:johan)
      @repository.save!
      @repository.reload
      assert @repository.writable_by?(users(:johan)), '@repository.writable_by?(users(:johan)) should be true'
      assert !@repository.writable_by?(users(:mike)), '@repository.writable_by?(users(:mike)) should be false'
    
      @repository.change_owner_to!(groups(:team_thunderbird))
      @repository.save!
      assert !@repository.writable_by?(users(:johan)), '@repository.writable_by?(users(:johan)) should be false'

      @repository.owner.add_member(users(:moe), Role.member)
      @repository.committerships.reload
      assert @repository.writable_by?(users(:moe)), '@repository.writable_by?(users(:moe)) should be true'
    end
    
    context "a wiki repository" do
      setup do
        @repository.kind = Repository::KIND_WIKI
      end
      
      should "be writable by everyone" do
        @repository.wiki_permissions = Repository::WIKI_WRITABLE_EVERYONE
        [:johan, :mike, :moe].each do |login|
          assert @repository.writable_by?(users(login)), "not writable_by #{login}"
        end
      end
      
      should "only be writable by project members" do
        @repository.wiki_permissions = Repository::WIKI_WRITABLE_PROJECT_MEMBERS
        assert @repository.project.member?(users(:johan))
        assert @repository.writable_by?(users(:johan))
        
        assert !@repository.project.member?(users(:moe))
        assert !@repository.writable_by?(users(:moe))
      end
    end
  end
  
  should "publishes a message on create and update" do
    p = proc{
      @repository.save!
    }
    message = find_message_with_queue_and_regexp('/queue/GitoriousRepositoryCreation', /create_git_repository/) {p.call}
    assert_equal 'create_git_repository', message['command']
    assert_equal 1, message['arguments'].size
    assert_match(/#{@repository.real_gitdir}$/, message['arguments'].first)
    assert_equal @repository.id, message['target_id'].to_i
  end

  should "publishes a message on clone" do
    p = proc{
      @repository.parent = repositories(:johans)
      @repository.save!
    }
    message = find_message_with_queue_and_regexp('/queue/GitoriousRepositoryCreation', /clone_git_repository/) {p.call}
    assert_equal "clone_git_repository", message['command']
    assert_equal 2, message['arguments'].size
    assert_match(/#{@repository.real_gitdir}$/, message['arguments'].first)
    assert_equal @repository.id, message['target_id']
  end
  
  should "creates a notification on destroy" do
    @repository.save!
    message = find_message_with_queue_and_regexp(
      '/queue/GitoriousRepositoryDeletion', 
      /delete_git_repository/) { @repository.destroy }
    assert_equal 'delete_git_repository', message['command']
    assert_equal 1, message['arguments'].size
    assert_match(/#{@repository.real_gitdir}$/, message['arguments'].first)
  end
  
  should "has one recent commit" do
    @repository.save!
    repos_mock = mock("Git mock")
    commit_mock = stub_everything("Git::Commit mock")
    repos_mock.expects(:commits).with("master", 1).returns([commit_mock])
    @repository.stubs(:git).returns(repos_mock)
    @repository.stubs(:has_commits?).returns(true)
    heads_stub = mock("head")
    heads_stub.stubs(:name).returns("master")    
    @repository.stubs(:head_candidate).returns(heads_stub)
    assert_equal commit_mock, @repository.last_commit
  end
  
  should "has one recent commit within a given ref" do
    @repository.save!
    repos_mock = mock("Git mock")
    commit_mock = stub_everything("Git::Commit mock")
    repos_mock.expects(:commits).with("foo", 1).returns([commit_mock])
    @repository.stubs(:git).returns(repos_mock)
    @repository.stubs(:has_commits?).returns(true)   
    @repository.expects(:head_candidate).never
    assert_equal commit_mock, @repository.last_commit("foo")
  end
  
  should "knows who can delete it" do
    @repository.kind = Repository::KIND_PROJECT_REPO
    assert !@repository.can_be_deleted_by?(users(:johan))
    @repository.project.repositories << new_repos(:name => "another")
    assert @repository.can_be_deleted_by?(users(:johan))
    
    @repository.kind = Repository::KIND_TEAM_REPO
    assert !@repository.can_be_deleted_by?(users(:moe))
    assert @repository.can_be_deleted_by?(users(:johan))
  end
  
  should "have a git method that accesses the repository" do
    # FIXME: meh for stubbing internals, need to refactor that part in Grit
    File.expects(:exist?).at_least(1).with("#{@repository.full_repository_path}/.git").returns(false)
    File.expects(:exist?).at_least(1).with(@repository.full_repository_path).returns(true)
    assert_instance_of Grit::Repo, @repository.git
    assert_equal @repository.full_repository_path, @repository.git.path
  end
  
  should "have a head_candidate" do
    head_stub = mock("head")
    head_stub.stubs(:name).returns("master")
    git = mock("git backend")
    @repository.stubs(:git).returns(git)
    git.expects(:head).returns(head_stub)
    @repository.expects(:has_commits?).returns(true)
    
    assert_equal head_stub, @repository.head_candidate
  end
  
  should "have a head_candidate, unless it doesn't have commits" do
    @repository.expects(:has_commits?).returns(false)
    assert_equal nil, @repository.head_candidate
  end
  
  should "has paginated_commits" do
    git = mock("git")
    commits = [mock("commit"), mock("commit")]
    @repository.expects(:git).times(2).returns(git)
    git.expects(:commit_count).returns(120)
    git.expects(:commits).with("foo", 30, 30).returns(commits)
    commits = @repository.paginated_commits("foo", 2, 30)
    assert_instance_of WillPaginate::Collection, commits
  end
  
  should "has a count_commits_from_last_week_by_user of 0 if no commits" do
    @repository.expects(:has_commits?).returns(false)
    assert_equal 0, @repository.count_commits_from_last_week_by_user(users(:johan))
  end
  
  should "returns a set of users from a list of commits" do
    commits = []
    users(:johan, :moe).map do |u|
      committer = OpenStruct.new(:email => u.email)
      commits << OpenStruct.new(:committer => committer, :author => committer)
    end
    users = @repository.users_by_commits(commits)
    assert_equal users(:johan, :moe).map(&:email).sort, users.keys.sort
    assert_equal users(:johan, :moe).map(&:login).sort, users.values.map(&:login).sort
  end
  
  should "know if it's a normal project repository" do
    assert @repository.project_repo?, '@repository.project_repo? should be true'
  end
  
  should "know if it's a wiki repo" do
    @repository.kind = Repository::KIND_WIKI
    assert @repository.wiki?, '@repository.wiki? should be true'
  end
  
  should "has a parent, which is the owner" do
    @repository.kind = Repository::KIND_TEAM_REPO
    @repository.owner = groups(:team_thunderbird)
    assert_equal groups(:team_thunderbird), @repository.breadcrumb_parent

    @repository.kind = Repository::KIND_USER_REPO
    @repository.owner = users(:johan)
    assert_equal users(:johan), @repository.breadcrumb_parent
  end
  
  should "has a parent, which is the project for mainlines" do
    @repository.kind = Repository::KIND_PROJECT_REPO
    @repository.owner = groups(:team_thunderbird)
    assert_equal projects(:johans), @repository.breadcrumb_parent
    
    @repository.owner = users(:johan)
    assert_equal projects(:johans), @repository.breadcrumb_parent
  end
  
  should " return its name as title" do
    assert_equal @repository.title, @repository.name
  end
  
  should "return the project title as owner_title if it's a mainline" do
    @repository.kind = Repository::KIND_PROJECT_REPO
    assert_equal @repository.project.title, @repository.owner_title
  end
  
  should "return the owner title as owner_title if it's not a mainline" do
    @repository.kind = Repository::KIND_TEAM_REPO
    assert_equal @repository.owner.title, @repository.owner_title
  end
  
  should "returns a list of committers depending on owner type" do
    repo = repositories(:johans2)
    repo.committerships.each(&:delete)
    repo.reload
    assert !repo.committers.include?(users(:moe))

    repo.committerships.create(:committer => users(:johan))
    assert_equal [users(:johan).login], repo.committers.map(&:login)
    
    repo.committerships.create(:committer => groups(:team_thunderbird))
    exp_users = groups(:team_thunderbird).members.unshift(users(:johan))
    assert_equal exp_users.map(&:login), repo.committers.map(&:login)
    
    groups(:team_thunderbird).add_member(users(:moe), Role.admin)
    repo.reload
    assert repo.committers.include?(users(:moe))
  end
  
  should "sets a hash on create" do
    assert @repository.new_record?, '@repository.new_record? should be true'
    @repository.save!
    assert_not_nil @repository.hashed_path
    assert_equal 3, @repository.hashed_path.split("/").length
    assert_match(/[a-z0-9\/]{42}/, @repository.hashed_path)
  end
  
  should "create the initial committership on create for owner" do
    group_repo = new_repos(:owner => groups(:team_thunderbird))
    assert_difference("Committership.count") do
      group_repo.save!
      assert_equal 1, group_repo.committerships.count
      assert_equal groups(:team_thunderbird), group_repo.committerships.first.committer
    end
    
    user_repo = new_repos(:owner => users(:johan), :name => "foo2")
    assert_difference("Committership.count") do
      user_repo.save!
      assert_equal 1, user_repo.committerships.count
      assert_equal users(:johan), user_repo.committerships.first.committer
    end
  end
  
  should "know the full hashed path" do
    assert_equal @repository.hashed_path, @repository.full_hashed_path
  end
  
  should "allow changing ownership from a user to a group" do
    repo = repositories(:johans)
    repo.change_owner_to!(groups(:team_thunderbird))
    assert_equal groups(:team_thunderbird), repo.owner
    repo.change_owner_to!(users(:johan))
    assert_equal groups(:team_thunderbird), repo.owner
  end

  should "not change kind when it's a project repo and changing owner" do
    repo = repositories(:johans)
    repo.change_owner_to!(groups(:team_thunderbird))
    assert_equal groups(:team_thunderbird), repo.owner
    assert_equal Repository::KIND_PROJECT_REPO, repo.kind
  end

  should "change kind when changing owner" do
    repo = repositories(:johans)
    repo.update_attribute(:kind, Repository::KIND_USER_REPO)
    assert repo.user_repo?
    repo.change_owner_to!(groups(:team_thunderbird))
    assert_equal groups(:team_thunderbird), repo.owner
    assert repo.team_repo?
  end
  
  should "changing ownership adds the new owner to the committerships" do
    repo = repositories(:johans)
    old_committer = repo.owner
    repo.change_owner_to!(groups(:team_thunderbird))
    assert !repo.committers.include?(old_committer)
  end
  
  should "downcases the name before validation" do
    repo = new_repos(:name => "FOOBAR")
    repo.save!
    assert_equal "foobar", repo.reload.name
  end
  
  should "have a project_or_owner" do
    repo = repositories(:johans)
    assert repo.project_repo?
    assert_equal repo.project, repo.project_or_owner

    repo.kind = Repository::KIND_TEAM_REPO
    repo.owner = groups(:team_thunderbird)
    assert_equal repo.owner, repo.project_or_owner
    
    repo.kind = Repository::KIND_TEAM_REPO
    repo.owner = groups(:team_thunderbird)
    assert_equal repo.owner, repo.project_or_owner
  end
  
  context "participant groups" do
    setup do
      @repo = repositories(:moes)
    end
    
    should "includes the groups' members in #committers" do
      assert @repo.committers.include?(groups(:team_thunderbird).members.first)
    end
    
    should "only include unique users in #committers" do
      groups(:team_thunderbird).add_member(users(:moe), Role.member)
      assert_equal 1, @repo.committers.select{|u| u == users(:moe)}.size
    end
  end
  
  context 'owners as User or Group' do
    setup do
      @repo = repositories(:moes)
    end
    
    should "return a list of the users who are admin for the repository if owned_by_group?" do
      @repo.change_owner_to!(groups(:a_team))
      assert_equal([users(:johan)], @repo.owners)
    end
    
    should 'not throw an error if transferring ownership to a group if the group is already a committer' do
      @repo.change_owner_to!(groups(:team_thunderbird))
      assert_equal([users(:mike)], @repo.owners)
    end
    
    should 'return the owner if owned by user' do
      @repo.change_owner_to!(users(:moe))
      assert_equal([users(:moe)], @repo.owners)
    end
  end
  
  should "create an event on create if it's a project repo" do
    repo = new_repos
    repo.kind = Repository::KIND_PROJECT_REPO
    assert_difference("repo.project.events.count") do
      repo.save!
    end
    assert_equal repo, Event.last.target
    assert_equal Action::ADD_PROJECT_REPOSITORY, Event.last.action
  end
  
  context "find_by_name_in_project" do
    should "find with a project" do
      Repository.expects(:find_by_name_and_project_id!).with(repositories(:johans).name, projects(:johans).id).once
      Repository.find_by_name_in_project!(repositories(:johans).name, projects(:johans))
    end
    
    should "find without a project" do
      Repository.expects(:find_by_name!).with(repositories(:johans).name).once
      Repository.find_by_name_in_project!(repositories(:johans).name)
    end    
  end
  
  context "observers" do
    should "sends an email to the admin if there's a parent" do
      Mailer.expects(:deliver_new_repository_clone).with(@repository).returns(true)
      @repository.parent = repositories(:johans)
      @repository.save!
    end
    
    should "does not send an email to the admin if there's not a parent parent" do
      Mailer.expects(:deliver_new_repository_clone).never
      @repository.parent = nil
      @repository.save!
    end

    should "not send an email if it is a tracking repository that's being created" do
      Mailer.expects(:deliver_new_repository_clone).never
      @repository.kind = Repository::KIND_TRACKING_REPO
      @repository.parent = repositories(:johans)
      @repository.save!
    end
  end
  
  context 'Signoff of merge requests' do
    setup do
      @project = projects(:johans)
      @mainline_repository = repositories(:johans)
      @other_repository = repositories(:johans2)
    end
    
    should 'know that the mainline repository requires signoff of merge requests' do
      assert @mainline_repository.mainline?
      assert @mainline_repository.requires_signoff_on_merge_requests?
    end
    
    should 'not require signoff of merge requests in other repositories' do
      assert !@other_repository.mainline?
      assert !@other_repository.requires_signoff_on_merge_requests?
    end
  end

  context "Merge request status tags" do
    setup {@repo = repositories(:johans)}

    should "have a list of used status tags" do
      assert_equal %w(open), @repo.merge_request_status_tags
    end
  end
  
  context "Thottling" do
    setup{ Repository.destroy_all }
    
    should "throttle on create" do      
      assert_nothing_raised do
        5.times{|i| new_repos(:name => "wifebeater#{i}").save! }
      end
      
      assert_no_difference("Repository.count") do
        assert_raises(RecordThrottling::LimitReachedError) do
          new_repos(:name => "wtf-are-you-doing-bro").save!
        end
      end
    end
  end
  
  context 'Logging updates' do
    setup {@repository = repositories(:johans)}
    
    should 'generate events for each value that is changed' do
      assert_incremented_by(@repository.events, :size, 1) do
        @repository.log_changes_with_user(users(:johan)) do
          @repository.replace_value(:name, "new_name")
        end
        assert @repository.save
      end
      assert_equal 'new_name', @repository.reload.name
    end
    
    should 'not generate events when blank values are provided' do
      assert_incremented_by(@repository.events, :size, 0) do
        @repository.log_changes_with_user(users(:johan)) do
          @repository.replace_value(:name, "")
        end
      end
    end
    
    should 'not generate events when invalid values are provided' do
      assert_incremented_by(@repository.events, :size, 0) do
        @repository.log_changes_with_user(users(:johan)) do
          @repository.replace_value(:name, "Some illegal value")
        end
      end      
    end
    
    should 'not generate events when a value is unchanged' do
      assert_incremented_by(@repository.events, :size, 0) do
        @repository.log_changes_with_user(users(:johan)) do
          @repository.replace_value(:name, @repository.name)
        end
      end      
    end
  end
  
  context "changing the HEAD" do
    setup do
      @grit = Grit::Repo.new(grit_test_repo("dot_git"), :is_bare => true)
      @repository.stubs(:git).returns(@grit)
    end
    
    should "change the head" do
      assert the_head = @grit.get_head("test/master")
      @grit.expects(:update_head).with(the_head).returns(true)
      @repository.head = the_head.name
    end
    
    should "not change the head if given a nonexistant ref" do
      @grit.expects(:update_head).never
      @repository.head = "non-existant"
      @repository.head = nil
      @repository.head = ""
    end
    
    should "change the head, even if the current head is nil" do
      assert the_head = @grit.get_head("test/master")
      @grit.expects(:head).returns(nil)
      @grit.expects(:update_head).with(the_head).returns(true)
      @repository.head = the_head.name
    end
  end

  context 'Merge request repositories' do
    setup do
      @project = Factory.create(:user_project)
      @main_repo = Factory.create(:repository, :project => @project, :owner => @project.owner, :user => @project.user)
    end
    
    should 'initially not have a merge request repository' do
      assert !@main_repo.has_tracking_repository?
    end
    
    should 'generate a tracking repository' do
      @merge_repo = @main_repo.create_tracking_repository
      assert @main_repo.project_repo?
      assert @merge_repo.tracking_repo?
      assert_equal @main_repo, @merge_repo.parent
      assert_equal @main_repo.owner, @merge_repo.owner
      assert_equal @main_repo.user, @merge_repo.user
      assert @main_repo.has_tracking_repository?
      assert_equal @merge_repo, @main_repo.tracking_repository
    end
    
    should 'not post a repository creation message for merge request repositories' do
      @merge_repo = @main_repo.build_tracking_repository
      @merge_repo.expects(:publish).never
      assert @merge_repo.save
    end
  end
end
