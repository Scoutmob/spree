# Use singleton class Spree::Preferences::Store.instance to access
#
# StoreInstance has a persistence flag that is on by default,
# but we disable database persistence in testing to speed up tests
#

require 'singleton'

module Spree::Preferences

  class StoreInstance
    attr_accessor :persistence
    attr_writer :perform_caching

    def initialize
      @cache = Rails.cache
      @persistence = true
      @perform_caching = true
    end

    def set(key, value, type)
      if perform_caching?
        @cache.write(key, value)
      end
      persist(key, value, type)
    end

    def exist?(key)
      (perform_caching? && @cache.exist?(key)) ||
      should_persist? && Spree::Preference.where(:key => key).exists?
    end

    def get(key,fallback=nil)
      if perform_caching?
        # return the retrieved value, if it's in the cache
        # use unless nil? incase the value is actually boolean false
        #
        unless (val = @cache.read(key)).nil?
          return val
        end
      end

      if should_persist?
        # If it's not in the cache, maybe it's in the database, but
        # has been cleared from the cache

        # does it exist in the database?
        if Spree::Preference.table_exists? && preference = Spree::Preference.find_by_key(key)
          if perform_caching?
            # it does exist, so let's put it back into the cache
            @cache.write(preference.key, preference.value)
          end

          # and return the value
          return preference.value
        end
      end

      if !fallback.nil? && perform_caching?
        # cache fallback so we won't hit the db above on
        # subsequent queries for the same key
        #
        @cache.write(key, fallback)
      end

      return fallback
    end

    def delete(key)
      if perform_caching?
        @cache.delete(key)
      end
      destroy(key)
    end

    def clear_cache
      if perform_caching?
        @cache.clear
      end
    end

    private

    def persist(cache_key, value, type)
      return unless should_persist?

      preference = Spree::Preference.where(:key => cache_key).first_or_initialize
      preference.value = value
      preference.value_type = type
      preference.save
    end

    def destroy(cache_key)
      return unless should_persist?

      preference = Spree::Preference.find_by_key(cache_key)
      preference.destroy if preference
    end

    def should_persist?
      @persistence and Spree::Preference.table_exists?
    end

    def perform_caching?
      @perform_caching
    end

  end

  class Store < StoreInstance
    include Singleton
  end

end
