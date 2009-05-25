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

class GroupTest < ActiveSupport::TestCase
    
  
  
  context "in general" do
    should "uses the name as to_param" do
      assert_equal groups(:team_thunderbird).name, groups(:team_thunderbird).to_param
    end

  end
  
  context "members" do
    setup do
      @group = groups(:team_thunderbird)
    end
    
    should "knows if a user is a member" do
      assert !@group.member?(users(:johan)), '@group.member?(users(:johan)) should be false'
      assert @group.member?(users(:mike)), '@group.member?(users(:mike)) should be true'
    end
    
    should "know the role of a member" do
      assert_equal nil, @group.role_of_user(users(:johan))
      assert_equal roles(:admin), @group.role_of_user(users(:mike))
      assert !@group.admin?(users(:johan)), '@group.admin?(users(:johan)) should be false'
      assert @group.admin?(users(:mike)), '@group.admin?(users(:mike)) should be true'
      
      assert !@group.committer?(users(:johan)), '@group.committer?(users(:johan)) should be false'
      assert @group.committer?(users(:mike)), '@group.committer?(users(:mike)) should be true'
    end
    
    should "can add a user with a role using add_member" do
      assert !@group.member?(users(:johan)), '@group.member?(users(:johan)) should be false'
      @group.add_member(users(:johan), Role.member)
      assert @group.reload.member?(users(:johan)), '@group.reload.member?(users(:johan)) should be true'
    end
  end
  
  context "Committerships" do
    setup do
      @group = groups(:team_thunderbird)
    end
    
    should "has a committership with a repository" do
      assert_equal repositories(:moes), committerships(:thunderbird_moes).repository
      assert_equal groups(:team_thunderbird), committerships(:thunderbird_moes).committer
      assert @group.participated_repositories.include?(repositories(:moes))
    end
  end
  
  context "repositories" do
    should "has many repositories" do
      assert groups(:team_thunderbird).repositories.include?(repositories(:johans2))
    end
    
    should "not have wiki repositories in #repositories" do
      wiki = repositories(:johans_wiki)
      wiki.owner = groups(:team_thunderbird)
      wiki.save!
      assert !groups(:team_thunderbird).repositories.include?(wiki)
    end
  end
  
  should "has to_param_with_prefix" do
    grp = groups(:team_thunderbird)
    assert_equal "+#{grp.to_param}", grp.to_param_with_prefix
  end
  
  should "has no breadcrumb parent" do
    assert_equal nil, groups(:team_thunderbird).breadcrumb_parent
  end
  
  should "has a collection of project ids, of all projects it's somehow associated with" do
    group = groups(:team_thunderbird)
    assert group.all_related_project_ids.include?(projects(:thunderbird).id)
    assert group.all_related_project_ids.include?(repositories(:johans2).project_id)
    assert group.all_related_project_ids.include?(projects(:moes).id)
  end
  
  should "know when it's deletable" do
    assert_equal 1, groups(:a_team).members.count
    assert groups(:a_team).deletable?
    groups(:a_team).add_member(users(:moe), Role.member)
    assert !groups(:a_team).deletable?
  end
  
  should 'not be deletable if it has projects associated' do
    group = groups(:a_team)
    assert_equal [], group.projects
    assert group.deletable?
    project = group.projects.build(:title => 'Mr T', :slug => 'mr_t', :description => 'Mister Ts project', :user => users(:moe))
    assert project.save
    assert_equal [project], group.projects
    assert !group.deletable?
  end
  
  context "validations" do
    should " have a unique name" do
      group = Group.new({
        :name => groups(:team_thunderbird).name
      })
      assert !group.valid?, 'valid? should be false'
      assert_not_nil group.errors.on(:name)
    end
    
    should " have a alphanumeric name" do
      group = Group.new({
        :name => "fu bar"
      })
      assert !group.valid?, 'group.valid? should be false'
      assert_not_nil group.errors.on(:name)
    end

    should 'require valid names' do
      ['foo_bar', 'foo.bar', 'foo bar'].each do |name|
        g = Group.new
        g.name = name
        assert !g.save
        assert_not_nil(g.errors.on(:name), "#{name} should not be a valid name")
      end
    end
    
    should 'automatically downcase the group name before validation' do
      g = Group.create(:name => 'FooWorkers')
      assert_equal('fooworkers', g.name)
    end
  end
  
  context 'Avatars' do
    setup {
      @group = groups(:team_thunderbird)
    }
    
    should 'have a default avatar' do
      assert_equal '/images/default_group_avatar.png', @group.avatar.url
    end
    
    should 'use the correct path when an avatar is set' do
      @group.avatar_file_name = 'foo.png'
      assert_equal '/system/group_avatars/team-thunderbird/original/foo.png', @group.avatar.url
    end
  end
end
