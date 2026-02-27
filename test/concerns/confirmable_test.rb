# frozen_string_literal: true

require_relative "../test_helper"

class ConfirmableTest < Minitest::Test
  class ConfirmHost
    include SolidQueueTui::Views::Confirmable

    attr_reader :last_executed_action

    def initialize
      init_confirm
      @last_executed_action = nil
    end

    def execute_confirm_action(action)
      @last_executed_action = action
    end

    def confirm_message
      "Are you sure?"
    end
  end

  def setup
    @host = ConfirmHost.new
  end

  def test_initial_state_not_confirming
    refute @host.confirm_mode?
  end

  def test_setting_action_enters_confirm_mode
    @host.instance_variable_set(:@confirm_action, :retry)
    assert @host.confirm_mode?
  end

  def test_y_executes_action
    @host.instance_variable_set(:@confirm_action, :retry)
    @host.handle_confirm_input({ type: :key, code: "y" })

    refute @host.confirm_mode?
    assert_equal :retry, @host.last_executed_action
  end

  def test_n_cancels
    @host.instance_variable_set(:@confirm_action, :retry)
    @host.handle_confirm_input({ type: :key, code: "n" })

    refute @host.confirm_mode?
    assert_nil @host.last_executed_action
  end

  def test_esc_cancels
    @host.instance_variable_set(:@confirm_action, :retry)
    @host.handle_confirm_input({ type: :key, code: "esc" })

    refute @host.confirm_mode?
    assert_nil @host.last_executed_action
  end

  def test_other_keys_ignored
    @host.instance_variable_set(:@confirm_action, :retry)
    @host.handle_confirm_input({ type: :key, code: "x" })

    assert @host.confirm_mode?
    assert_nil @host.last_executed_action
  end
end
