class WidgetsController < ApplicationController
  WIDGET_TYPES = %w(account project stack organization)

  helper :widgets
  before_action :set_widget, except: :index
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  layout :false, except: :index
  before_action :handle_xml_format, except: :index
  skip_before_action :verify_authenticity_token
  after_action :allow_iframe

  private

  def record_not_found
    render text: I18n.t('widgets.not_found')
  end

  def set_widget
    widget_name = action_name.split('_') - WIDGET_TYPES
    @widget = Object.const_get("#{controller_name.camelize[0..-2]}::#{widget_name.join('_').camelize}").new(params)
  end

  def render_image_for_gif_format
    return unless request.format.gif?
    send_data(@widget.image, disposition: 'inline', type: 'image/gif', filename: 'widget.gif', status: 200)
  end

  def render_not_supported_for_gif_format
    return unless request.format.gif?
    image = WidgetBadge::Thin.create([text: 'Not supported'])
    send_data(image, disposition: 'inline', type: 'image/gif', filename: 'widget.gif', status: 406)
  end

  def render_iframe_for_js_format
    return unless request.format.js?
    render :iframe
  end

  def handle_xml_format
    return unless request_format == 'xml'
    @type = WIDGET_TYPES.select { |klass| controller_name.include?(klass) }[0]
    @parent = @widget.send(@type)
    fail ParamRecordNotFound unless @parent
    render template: 'widgets/metadata'
  end
end
