class CreditcardsController < ApplicationController
  before_filter :load_data, :only => [:new, :update, :create]
  rescue_from Spree::GatewayError, :with => :rescue_from_spree_gateway_error
  #resource_controller
  #before_update :hello

  def new
    @creditcard = Creditcard.new
    @address = @creditcard.build_address
  end

  def create 
    # cim_gateway gets us the actual AuthorizeNetCIM from ActiveMerchant
    # and we have to delete the old profile because we don't want to
    # accidentally create a duplicate
    @creditcard = @subscription.build_creditcard(params[:creditcard])
    #@creditcard.address = @subscription.legacy_address
    if @subscription.save
      if @subscription.is_arb?
        gateway = Gateway.find(:first, :conditions => {:type => "Gateway::AuthorizeNetCim", :active => true, :environment => Rails.env})
        # Create the payment profile for this card
        gateway.create_profile_from_card( @subscription.creditcard )
        @subscription.migrate_arb_to_cim
      end
      @subscription.reactivate if @subscription.inactive? 
      flash[:notice] = "Payment method for subscription was updated successfully"
      redirect_to subscription_path(@subscription) 
    else
      flash[:error]  = "There was a problem updating payment method for this subscription. Please try again"
      render :action => 'new'
    end
  end
  
  def edit
    @creditcard = Creditcard.find(params[:id])
    @creditcard.updating_from_user_account = true
    @address = @creditcard.build_address if @creditcard.address.nil?
  end

  def update
    @creditcard = Creditcard.find(params[:id])
    @creditcard.updating_from_user_account = true
    gateway = Gateway.find(:first, :conditions => {:type => "Gateway::AuthorizeNetCim", :active => true, :environment => Rails.env})
    if @creditcard.update_attributes(params[:creditcard])
      gateway.create_customer_payment_profile_from_card(@creditcard)
      @subscription.reactivate if @subscription.inactive? 
      flash[:notice] = "Payment method for subscription was updated successfully"
      redirect_to subscription_path(@subscription) 
    else
      flash[:error]  = "There was a problem updating payment method for this subscription. Please try again"
      render :action => "edit"
    end
  end


  #update.success.wants.html { redirect_to subscription_path(@subscription) }
  #create.success.wants.html { redirect_to subscription_path(@subscription) }


  private
  def load_data
    @subscription = Subscription.find(params[:subscription_id])
  end

 def rescue_from_spree_gateway_error
    flash[:error] = t('spree_gateway_error_flash_for_checkout')
    render :edit
  end
  
end
