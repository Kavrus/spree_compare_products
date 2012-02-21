class CompareProductsController < Spree::BaseController
  include ProductsHelper
  
  COMPARE_LIMIT = 7
  before_filter :find_taxon, :only => :show

  def show
    if @comparable_products.count > 1
      @properties = @comparable_products.map do |product|
        product.taxon.properties.map do |prop|
          if prop.type_uid == UID_SET_OF_PROPERTIES && prop.children.any?
            prop.children
          else
            prop
          end
        end
      end
      @properties = @properties.flatten.uniq
    else
      flash[:error] = I18n.t(:insufficient_data, :scope => :compare_products)
    end
  end

  def add
    product = Product.find(params[:id])
    if product && product.taxon.is_comparable?
      if session[:comparable_product_ids].include?(product.id)
        flash.now[:notice] = I18n.t(:already_in_list, :product => product_title(product), :scope => :compare_products)
        @already_in_list = "true"
      else
        if @comparable_products.size < COMPARE_LIMIT
          @added_product = product
          session[:comparable_product_ids] << product.id
          flash.now[:notice] = I18n.t(:added_to_comparsion, :product => product_title(product), :scope => :compare_products)
        else
          flash.now[:notice] = I18n.t(:limit_is_reached, :scope => :compare_products, :count => COMPARE_LIMIT)
        end
      end
    else
      flash[:error] = I18n.t(:taxon_not_comparable, :scope => :compare_products)
    end
    respond_to do |format|
      format.html { redirect_back_or_default(product) }
      format.js do
        find_comparable_products
        render :layout => false
      end
    end
  end

  def remove
    session[:comparable_product_ids] ||= []
    product = Product.find_by_permalink(params[:id])
    if product
      @deleted_product = product if session[:comparable_product_ids].include?(product.id)
      session[:comparable_product_ids].delete(product.id)
      flash.now[:notice] = I18n.t(:removed_from_comparsion, :product => product_title(product), :scope => :compare_products)
    end
    respond_to do |format|
      format.html do
        if request.referer.include?('compare_products') && session[:comparable_product_ids].size > 1
          redirect_to compare_products_url
        else
          redirect_back_or_default(product)
        end
      end
      format.js { render :layout => false }
    end
  end
  
  def remove_similar
    if session[:similar_products_ids].present?
      session[:similar_products_ids].delete(params[:id])
      if session[:similar_products_ids].size > 1
        redirect_to request.referer
      else session[:similar_products_ids].size == 1
        redirect_to product_url(session[:similar_products_ids].first)
      end
    else
      redirect_to :home
    end
  end

  def destroy
    session[:comparable_product_ids] = []
    flash[:notice] = I18n.t(:comparsion_cleared, :scope => :compare_products)
    respond_to do |format|
      format.html { redirect_back_or_default(catalog_path) }
      format.js { render :layout => false }
    end
  end
  
  def similar
    unless request.referer.include?("compare_products/similar")
      session[:similar_products_ids] = Product.find(params[:id]).similar_products.map{|p| p.id.to_s}.unshift(params[:id])
    end
    
    @similar_products = Product.where(:id => session[:similar_products_ids])
    
    @properties = @similar_products.map do |product|
      product.taxon.properties.map do |prop|
        if prop.type_uid == UID_SET_OF_PROPERTIES && prop.children.any?
          prop.children
        else
          prop
        end
      end
    end
    @properties = @properties.flatten.uniq
    
    render :show
  end

  private

  def find_taxon
    if @comparable_products.size > 1
      @taxon = @comparable_products.last.taxon if @comparable_products.last.taxon.is_comparable?
      if @taxon.nil?
        flash[:error] = I18n.t(:invalid_taxon, :scope => :compare_products)
      end
    elsif @comparable_products.size == 1
      @taxon = @comparable_products.first.taxon if @comparable_products.first.taxon.is_comparable?
    end
  end
end
