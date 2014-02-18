# Autoscope

[![Build Status](https://travis-ci.org/dlangevin/autoscope.png?branch=master)](https://travis-ci.org/dlangevin/autoscope)

[![Code Climate](https://codeclimate.com/repos/53035ea369568029d4003926/badges/6d471a858ab8114d9cc7/gpa.png)](https://codeclimate.com/repos/53035ea369568029d4003926/feed)

[![Code Climate](https://codeclimate.com/repos/53035ea369568029d4003926/badges/6d471a858ab8114d9cc7/coverage.png)](https://codeclimate.com/repos/53035ea369568029d4003926/feed)

Apply scopes to any model based on params from a controller

## Installation

Add this line to your application's Gemfile:

    gem 'autoscope'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install autoscope

## Usage

### Define scopes normally in your Model

    class MyClass < ActiveRecord::Base
      scope :noargs, -> { where(a: 'b') }
      scope :one_arg, -> a { where(a: a) }
      scope :varargs, -> *a { where(a: a)}
    end

### Now we can apply these scopes from a Controller (or elsewhere)

    class MyController < ApplicationController
      # GET /my_controller
      def index
        @records = MyClass.add_scopes(params)
        respond_with(@records)
      end

### Passing params

#### Scopes without params
    GET /my_controller?noargs=ANY_VALUE

#### Scopes with a finite set of named params
These use the name of the scope and the name of the parameter(s)
defined in the scope
    
    GET /my_controller?one_arg[a]=MY_VAL

#### Scopes with varargs
You can just supply an Array to these
    
    GET /my_controller?varargs[a][]=MY_VAL&varargs[a][]=OTHER_VAL

### Appending to existing scopes
You can start with an existing scope if you have other criteria that
you want to specify (for example access control in a Controller)

    class MyController < ApplicationController
      # GET /my_controller
      def index
        @records = MyClass.add_scopes(params, current_user.my_classes)
        respond_with(@records)
      end
    end

You can also add other criteria after `.add_scopes` is called

    @records = MyClass.add_scopes(params).active.future

### Built-in defaults

There are a few built-in "scopes" that you get for free:

    # Equivalent to MyClass.where(id: [1, 2])
    MyClass.add_scopes(ids: [1, 2])

    # Equivalent to MySubclass.all (any subclass of MyClass)
    MyClass.add_scopes(type: 'MySubclass')

    # Equivalent to MySubclass.paginate(page:3, per_page: 20)
    # This integrates with will_paginate
    MyClass.add_scopes(page: 3, per_page: 20)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
