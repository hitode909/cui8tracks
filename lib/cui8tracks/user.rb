class CUI8Tracks::User
  include CUI8Tracks::Thing

  %w{ toggle_follow follow unfollow}.each{ |method|
    eval <<-EOS
      def #{method}
        api.post(path('#{method}'))
      end
    EOS
  }

end
