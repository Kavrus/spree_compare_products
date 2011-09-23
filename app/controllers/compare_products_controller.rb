class CompareProductsController < Spree::BaseController
  COMPARE_LIMIT = 7
  before_filter :find_taxon, :only => :show

  helper :products, :taxons

  def show
    if @comparable_products.count > 1
      @properties = @comparable_products.includes(:product_properties => :property).map(&:properties).flatten.uniq # We return the list of properties here so we can use them latter.
    else
      flash[:error] = I18n.t(:insufficient_data, :scope => :compare_products)
    end
  end

  def add
    product = Product.find_by_permalink(params[:id])
    if product && product.taxon.is_comparable?
      if session[:comparable_product_ids].include?(product.id)
        flash[:notice] = I18n.t(:already_in_list, :product => product.name, :scope => :compare_products)
      else
        if @comparable_products.size < COMPARE_LIMIT
          @added_product = product
          session[:comparable_product_ids] << product.id
          flash[:notice] = I18n.t(:added_to_comparsion, :product => product.name, :scope => :compare_products)
        else
          flash[:notice] = I18n.t(:limit_is_reached, :scope => :compare_products, :count => COMPARE_LIMIT)
        end
      end
    else
      flash[:error] = I18n.t(:taxon_not_comparable, :scope => :compare_products)
    end
    respond_to do |format|
      format.html { redirect_back_or_default(product) }
      format.js { render :layout => false }
    end
  end

  def remove
    session[:comparable_product_ids] ||= []
    product = Product.find_by_permalink(params[:id])
    if product
      @deleted_product = product if session[:comparable_product_ids].include?(product.id)
      session[:comparable_product_ids].delete(product.id)
      flash[:notice] = I18n.t(:removed_from_comparsion, :product => product.name, :scope => :compare_products)
    end
    respond_to do |format|
      format.html { redirect_back_or_default(product) }
      format.js { render :layout => false }
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
    products_ids = params[:compare_products_ids] << params[:id]
    @similar_products = Product.where(:id => products_ids)
    @taxon = @similar_products.first.taxon
    @properties = @similar_products.includes(:product_properties => :property).map(&:properties).flatten.uniq
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
