#--
# Copyright (c) 2005-2010, John Mettraux, jmettraux@gmail.com
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# Made in Japan.
#++

require 'dm-core'
require 'ruote/storage/base'
require 'ruote/dm/version'


module Ruote
module Dm

  class Document
    include DataMapper::Resource

    property :ide, String, :key => true, :required => true
    property :rev, Integer, :key => true, :required => true
    property :typ, String, :key => true, :required => true
    property :doc, Text, :length => 2**32 - 1, :required => true, :lazy => false
  end

  class DmStorage

    include Ruote::StorageBase

    attr_reader :repository

    def initialize (repository=nil, options={})

      @options = options
      @repository = repository

      put_configuration
    end

    def put (doc, opts={})

      DataMapper.repository(@repository) do

        d = Document.first(:ide => doc['_id'], :typ => doc['type'])

        return Rufus::Json.decode(d.doc) if d && d.rev != doc['_rev']

        if doc['_rev'].nil?

          Document.new(
            :ide => doc['_id'],
            :rev => 0,
            :typ => doc['type'],
            :doc => Rufus::Json.encode(doc.merge('_rev' => 0))
          ).save

          doc['_rev'] = 0 if opts[:update_rev]

        else

          return true unless d

          d.rev = d.rev + 1
          d.doc = Rufus::Json.encode(doc.merge('_rev' => d.rev))
          d.save

          doc['_rev'] = d.rev if opts[:update_rev]
        end

        nil
      end
    end

    def get (type, key)

      DataMapper.repository(@repository) do
        d = Document.first(:typ => type, :ide => key)
        d ? Rufus::Json.decode(d.doc) : nil
      end
    end

    def delete (doc)

      raise ArgumentError.new('no _rev for doc') unless doc['_rev']

      DataMapper.repository(@repository) do

        d = Document.first(
          :typ => doc['type'], :ide => doc['_id'], :rev => doc['_rev'])

        return true unless d

        d.destroy!

        nil
      end
    end

    def get_many (type, key=nil, opts={})

      q = { :typ => type }

      DataMapper.repository(@repository) do
        Document.all(q).collect { |d| Rufus::Json.decode(d.doc) }
      end
    end

    def ids (type)

      DataMapper.repository(@repository) do
        Document.all(:typ => type).collect { |d| d.ide }
      end
    end

    def purge!

      #@dbs.values.each { |db| db.purge! }
    end

    #def dump (type)
    #  @dbs[type].dump
    #end

    def shutdown

      #@dbs.values.each { |db| db.shutdown }
    end

    # Mainly used by ruote's test/unit/ut_17_storage.rb
    #
    def add_type (type)

      # does nothing, types are differentiated by the 'typ' column
    end

    # Nukes a db type and reputs it (losing all the documents that were in it).
    #
    def purge_type! (type)

      DataMapper.repository(@repository) do
        Document.all(:typ => type).destroy!
      end
    end

    # A provision made for workitems, allow to query them directly by
    # participant name.
    #
    def by_participant (type, participant_name)

      #raise NotImplementedError if type != 'workitems'
      #@dbs['workitems'].by_participant(participant_name)
    end

    def by_field (type, field, value=nil)

      #raise NotImplementedError if type != 'workitems'
      #@dbs['workitems'].by_field(field, value)
    end

    protected

    # Don't put configuration if it's already in
    #
    # (avoid storages from trashing configuration...)
    #
    def put_configuration

      return if get('configurations', 'engine')

      conf = { '_id' => 'engine', 'type' => 'configurations' }.merge!(@options)
      put(conf)
    end
  end
end
end
