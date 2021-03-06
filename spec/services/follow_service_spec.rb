require 'rails_helper'

RSpec.describe FollowService do
  let(:sender) { Fabricate(:account, username: 'alice') }

  subject { FollowService.new }

  context 'local account' do
    describe 'locked account' do
      let(:bob) { Fabricate(:user, email: 'bob@example.com', account: Fabricate(:account, locked: true, username: 'bob')).account }

      before do
        subject.call(sender, bob.acct)
      end

      it 'creates a follow request' do
        expect(FollowRequest.find_by(account: sender, target_account: bob)).to_not be_nil
      end
    end

    describe 'unlocked account' do
      let(:bob) { Fabricate(:user, email: 'bob@example.com', account: Fabricate(:account, username: 'bob')).account }

      before do
        subject.call(sender, bob.acct)
      end

      it 'creates a following relation' do
        expect(sender.following?(bob)).to be true
      end
    end
  end

  context 'remote account' do
    describe 'locked account' do
      let(:bob) { Fabricate(:user, email: 'bob@example.com', account: Fabricate(:account, locked: true, username: 'bob', domain: 'example.com', salmon_url: 'http://salmon.example.com')).account }

      before do
        stub_request(:post, "http://salmon.example.com/").to_return(:status => 200, :body => "", :headers => {})
        subject.call(sender, bob.acct)
      end

      it 'creates a follow request' do
        expect(FollowRequest.find_by(account: sender, target_account: bob)).to_not be_nil
      end

      it 'sends a follow request salmon slap' do
        expect(a_request(:post, "http://salmon.example.com/").with { |req|
          xml = OStatus2::Salmon.new.unpack(req.body)
          xml.match(TagManager::VERBS[:request_friend])
        }).to have_been_made.once
      end
    end

    describe 'unlocked account' do
      let(:bob) { Fabricate(:user, email: 'bob@example.com', account: Fabricate(:account, username: 'bob', domain: 'example.com', salmon_url: 'http://salmon.example.com')).account }

      before do
        stub_request(:post, "http://salmon.example.com/").to_return(:status => 200, :body => "", :headers => {})
        subject.call(sender, bob.acct)
      end

      it 'creates a following relation' do
        expect(sender.following?(bob)).to be true
      end

      it 'sends a follow salmon slap' do
        expect(a_request(:post, "http://salmon.example.com/").with { |req|
          xml = OStatus2::Salmon.new.unpack(req.body)
          xml.match(TagManager::VERBS[:follow])
        }).to have_been_made.once
      end
    end
  end
end
