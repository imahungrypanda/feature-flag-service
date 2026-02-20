# frozen_string_literal: true

class GraphqlController < ApplicationController
  before_action :authenticate_bearer!

  def execute
    variables = prepare_variables(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]
    context = {
      # Query context goes here, for example:
      # current_user: current_user,
    }
    result = FeatureFlagServiceSchema.execute(query, variables: variables, context: context, operation_name: operation_name)
    render json: result
  rescue StandardError => e
    raise e unless Rails.env.development?
    handle_error_in_development(e)
  end

  private

  def authenticate_bearer!
    token = bearer_token
    expected = expected_api_token
    if expected.blank?
      Rails.logger.warn "Feature flag API token not configured (set FEATURE_FLAG_API_TOKEN or use credentials)"
      render json: { errors: [{ message: "Unauthorized" }] }, status: :unauthorized
      return
    end
    unless token.present? && ActiveSupport::SecurityUtils.secure_compare(token, expected)
      render json: { errors: [{ message: "Unauthorized" }] }, status: :unauthorized
    end
  end

  def bearer_token
    auth = request.authorization
    return nil unless auth&.start_with?("Bearer ")
    auth.sub(/\ABearer /i, "").strip.presence
  end

  def expected_api_token
    ENV["FEATURE_FLAG_API_TOKEN"].presence ||
      Rails.application.credentials.dig(:feature_flag_api_token)
  end

  # Handle variables in form data, JSON body, or a blank value
  def prepare_variables(variables_param)
    case variables_param
    when String
      if variables_param.present?
        JSON.parse(variables_param) || {}
      else
        {}
      end
    when Hash
      variables_param
    when ActionController::Parameters
      variables_param.to_unsafe_hash # GraphQL-Ruby will validate name and type of incoming variables.
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{variables_param}"
    end
  end

  def handle_error_in_development(e)
    logger.error e.message
    logger.error e.backtrace.join("\n")

    render json: { errors: [{ message: e.message, backtrace: e.backtrace }], data: {} }, status: 500
  end
end
