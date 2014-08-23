require_relative '../test_case'

module RackRabbit
  class TestSubscriber < TestCase

    #--------------------------------------------------------------------------

    def test_subscribe_lifecycle

      subscriber = build_subscriber
      rabbit     = subscriber.rabbit

      assert_equal(false, rabbit.started?)  
      assert_equal(false, rabbit.connected?)

      subscriber.subscribe
      assert_equal(true, rabbit.started?)
      assert_equal(true, rabbit.connected?)

      subscriber.unsubscribe
      assert_equal(false, rabbit.started?)
      assert_equal(false, rabbit.connected?)

    end

    #--------------------------------------------------------------------------

    def test_subscribe_options
      options    = { :queue => QUEUE, :exchange => EXCHANGE, :exchange_type => :fanout, :routing_key => ROUTE, :ack => true }
      subscriber = build_subscriber(options)
      rabbit     = subscriber.rabbit
      subscriber.subscribe
      assert_equal(options, rabbit.subscribe_options, "subscription options should be set as expected")
    end

    #--------------------------------------------------------------------------

    def test_subscribe_handles_message

      subscriber = build_subscriber(:app_id => APP_ID)
      message    = build_message
      rabbit     = subscriber.rabbit

      prime(subscriber, message)

      assert_equal([], rabbit.subscribed_messages, "preconditions")

      subscriber.subscribe

      assert_equal([message], rabbit.subscribed_messages)
      assert_equal([],        rabbit.published_messages)
      assert_equal([],        rabbit.acked_messages)
      assert_equal([],        rabbit.rejected_messages)
      assert_equal([],        rabbit.requeued_messages)

    end

    #--------------------------------------------------------------------------

    def test_handle_message_that_expects_a_reply

      subscriber = build_subscriber(:app_id => APP_ID) 
      message    = build_message(:delivery_tag => DELIVERY_TAG, :reply_to => REPLY_TO, :correlation_id => CORRELATION_ID)
      rabbit     = subscriber.rabbit

      prime(subscriber, message)

      subscriber.subscribe

      assert_equal([message],      rabbit.subscribed_messages)
      assert_equal([],             rabbit.acked_messages)
      assert_equal([],             rabbit.rejected_messages)
      assert_equal([],             rabbit.requeued_messages)
      assert_equal(1,              rabbit.published_messages.length)
      assert_equal(APP_ID,         rabbit.published_messages[0][:app_id])
      assert_equal(REPLY_TO,       rabbit.published_messages[0][:routing_key])
      assert_equal(CORRELATION_ID, rabbit.published_messages[0][:correlation_id])
      assert_equal(200,            rabbit.published_messages[0][:headers][RackRabbit::HEADER::STATUS])
      assert_equal("ok",           rabbit.published_messages[0][:body])

    end

    #--------------------------------------------------------------------------

    def test_succesful_message_is_acked

      subscriber = build_subscriber(:ack => true)
      message    = build_message(:delivery_tag => DELIVERY_TAG)
      rabbit     = subscriber.rabbit

      prime(subscriber, message)

      subscriber.subscribe

      assert_equal([message],      rabbit.subscribed_messages)
      assert_equal([],             rabbit.published_messages)
      assert_equal([DELIVERY_TAG], rabbit.acked_messages)
      assert_equal([],             rabbit.rejected_messages)
      assert_equal([],             rabbit.requeued_messages)

    end

    #--------------------------------------------------------------------------

    def test_failed_message_is_rejected

      subscriber = build_subscriber(:rack_file => ERROR_RACK_APP, :ack => true)
      message    = build_message(:delivery_tag => DELIVERY_TAG)
      response   = build_response(500, "uh oh")
      rabbit     = subscriber.rabbit

      prime(subscriber, [message, response])

      subscriber.subscribe

      assert_equal([message],               rabbit.subscribed_messages)
      assert_equal([],                      rabbit.published_messages)
      assert_equal([],                      rabbit.acked_messages)
      assert_equal([DELIVERY_TAG],          rabbit.rejected_messages)
      assert_equal([],                      rabbit.requeued_messages)

    end

    #==========================================================================
    # PRIVATE IMPLEMTATION HELPERS
    #==========================================================================

    private

    def prime(subscriber, *messages)
      messages.each do |m|
        m, r = m if m.is_a?(Array)
        r ||= build_response(200, "ok")
        subscriber.rabbit.prime(m)
        subscriber.handler.expects(:handle).with(m).returns(r)
      end
    end

    #--------------------------------------------------------------------------


  end # class TestSubscriber
end # module RackRabbit

