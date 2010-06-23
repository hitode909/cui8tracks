class EightTracks::User
  include EightTracks::Thing

  %w{ toggle_follow follow unfollow}.each{ |method|
    eval <<-EOS
      def #{method}
        got = api.post(path('#{method}'))
        got['user']['followed_by_current_user']
      end
    EOS
  }

end
