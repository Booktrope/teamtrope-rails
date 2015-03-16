class ProjectsController < ApplicationController
	before_action :signed_in_user #, only: [:show, :index, :destroy, :edit]
  before_action :set_project, except: [:create, :new, :index]

  def index
  	@projects = Project.all
  end
  
  def new
  	@project = Project.new
  end

  def edit
  end
  
  def create
  	@project = Project.new(new_project_params)
  	if @project.save
  		flash[:success] = "New Project Created!"
  		redirect_to projects_path
  	else
  		render 'new'
  	end
  end
  
  def destroy
    @project.destroy
    flash[:notice] = "Project has been destroyed."
    redirect_to projects_path
  end
    
  def update
		if @project.update(update_project_params)
			flash[:success] = "Updated"
			redirect_to @project
		else
			if params[:submitted_from_action] && params[:submitted_from_action] == 'show'
				render 'show'
			else
				render 'edit'
			end
		end
  end
  
  def show
		@activities = PublicActivity::Activity.order("created_at DESC").where(trackable_type: "Project", trackable_id: @project)
    @users = User.all
  end
  
  
  # form actions
  # TODO: form_data is now saved using to_s instead of passing the params array.
  # this prevents a crash when there is a temp file in params. Might want to come up with 
  # a cleaner solution

	def update_status
		if @project.update(update_project_params)
			@project.create_activity :update_status, owner: current_user,
                               parameters: { text: ' posted a status update', form_data: params[:project].to_s}
      update_current_task
      
			flash[:success] = 'Posted Status Update'
			redirect_to @project
		else
			render 'show'
		end
	end

  def accept_team_member
    if @project.update(update_project_params)
      @project.create_activity :accept_team_member, owner: current_user,
                               parameters: { text: ' added new team member', form_data: params[:project].to_s}
      update_current_task
      Booktrope::ParseWrapper.save_revenue_allocation_record_to_parse @project, current_user, DateTime.parse("#{params[:effective_date][:year]}/#{params[:effective_date][:month]}/#{params[:effective_date][:day]}")

      #TODO: Hellosign-rails integration

      flash[:success] = 'Accepted a Team Member'
      redirect_to @project
    else
      render 'show'
    end
  end

  def edit_complete_date
  	if @project.update(update_project_params)
  		@project.create_activity :submitted_edit_complete_date, owner: current_user, parameters: { text: " set the 'Edit Complete Date' to #{@project.edit_complete_date.strftime("%Y/%m/%d")}", form_data: params[:project].to_s}
  		flash[:success] = "Edit Complete Date Set"
			update_current_task	
  		redirect_to @project
  	else
  		render 'show'
  	end
  end
  
  # sets the revenue allocation per team_membership
  def revenue_allocation_split
  	if @project.update(update_project_params)

  		@project.create_activity :revenue_allocation_split, owner: current_user, parameters: { text: " set the revenue allocation split", form_data: params[:project][:team_memberships_attributes].to_s}						
			update_current_task			
			Booktrope::ParseWrapper.save_revenue_allocation_record_to_parse @project, current_user, DateTime.parse("#{params[:effective_date][:year]}/#{params[:effective_date][:month]}/#{params[:effective_date][:day]}")
  		
  		#TODO: Hellosign-rails integration
  		  		
	  	flash[:success] = "Revenue Allocation Split Set"
	  	redirect_to @project
	  else
	  	render 'show'
	  end
  end
  
  def original_manuscript
  	if @project.update(update_project_params)
  		@project.create_activity :submitted_original_manuscript, owner: current_user, parameters: {text: "Uploaded the Original Manuscript", form_data: params[:project].to_s}
  		flash[:success] = "Original Manuscript Uploaded"
  		update_current_task  		
  		redirect_to @project
  	else
  		render 'show'
  	end
  end
  
  def edited_manuscript
  	if @project.update(update_project_params)
  		@project.create_activity :submitted_edited_manuscript, owner: current_user, parameters: {text: "Uploaded the Edited Manuscript", form_data: params[:project].to_s}
  		update_current_task
  		flash[:success] = "Edited Manuscript Uploaded"
  		redirect_to @project
  	else
  		render 'show'
  	end
  end
  
  def proofed_manuscript
  	if @project.update(update_project_params)
  		@project.create_activity :submitted_proofed_manuscript, owner: current_user, parameters: {text: "Uploaded the Proofed Manuscript", form_data: params[:project].to_s}
  		update_current_task
  		flash[:success] = "Proofed Manuscript Uploaded"
  		redirect_to @project
  	else
  		render 'show'
  	end
  end

  def layout_upload
    if @project.update(update_project_params)
      @project.create_activity :uploaded_layout, owner: current_user,
                               parameters: {text: "Uploaded the Layout", form_data: params[:project].to_s}
      flash[:success] = "Layout Uploaded"
      update_current_task
      redirect_to @project
    else
      render 'show'
    end
  end

  def cover_concept_upload
    if @project.update(update_project_params)
      @project.create_activity :uploaded_cover_concept, owner: current_user,
                               parameters: {text: 'Uploaded the Cover Concept', form_data: params[:project].to_s}
      flash[:success] = 'Cover Concept Uploaded'
      update_current_task
      redirect_to @project
    else
      flash[:error] = 'Error uploading Cover Concept'
      render 'show'
    end
  end

  def edit_control_numbers
    @control_number = @project.control_number
    @control_number ||= @project.build_control_number

    if @control_number.update(update_control_number_params)
      # Update the record in Parse
      Booktrope::ParseWrapper.update_project_control_numbers @control_number

      # Record activity here
      @project.create_activity :updated_control_numbers, owner: current_user,
                               parameters: {text: "Updated the Control Numbers", form_data: params[:project].to_s}
      flash[:success] = "Updated the Control Numbers"
    else
      render 'show'
    end

    redirect_to @project
  end

  def edit_layout_style
    if @project.update(update_project_params)
      @project.create_activity :edited_layout_style, owner: current_user,
                               parameters: {text: 'Chose Layout Style', form_data: params[:project].to_s}
      flash[:success] = 'Layout Style Updated'
      update_current_task
      redirect_to @project
    else
      render 'show'
    end
  end

  def approve_layout
    # Set the approval date
    @project.touch(:layout_approved_date)

    if @project.update(update_project_params)
      update_current_task
      activity_text = (:approved_layout == 'approved_revisions') ? 'Approved the layout' : 'Approved the layout with changes'
      @project.create_activity :approved_layout, owner: current_user,
                               parameters: { text: activity_text, form_data: params[:project].to_s }
      flash[:success] = 'Approved the Layout'
      redirect_to @project
    else
      render 'show'
    end
  end

	def price_promotion
			
		if @project.update(update_project_params)
		
			@project.create_activity :submitted_price_promotion, owner: current_user,
                               parameters: {text: 'submitted a price promotion', 
                               form_data: params[:project].to_s}
                               
			update_current_task
			flash[:success] = 'Price Promotion Submitted.'
			redirect_to @project
		else
			render 'show'
		end
		
	end

  def approve_cover_art
    # This is an attribute accessor used as a flag for deciding what to update below
    approved = (params[:project][:cover_art_approval_decision] == 'true')

    if approved
      # Set the approval date
      @project.touch(:cover_art_approval_date)
      @project.update_attribute(:cover_concept_notes, nil)
      update_current_task
      activity_text = 'Approved the Cover Art'
      flash[:success] = activity_text
    else
    # Not approved, revert to previous step
      if @project.update_attribute(:cover_concept_notes, params[:project][:cover_concept_notes])
        reject_current_task
        activity_text = 'Rejected the Cover Art'
        flash[:success] = activity_text
      else
        # Some sort of failure updating the model.
        flash[:error] = 'An error occurred during update'
        render 'show'
      end
    end

    if ! activity_text.nil?
      @project.create_activity :approved_cover_art, owner: current_user,
                               parameters: { text: activity_text, form_data: params[:project].to_s }
      redirect_to @project
    end
  end

  def update_final_page_count
    if @project.update(update_project_params)
      update_current_task
      @project.create_activity :updated_final_page_count, owner: current_user,
                                parameters: { text: 'Updated Final Page Count', form_data: params[:project].to_s}
      flash[:success] = 'Updated Final Page Count'
      redirect_to @project
    else
        render 'show'
    end
  end
  
  def final_manuscript
  	if @project.update(update_project_params)
  		update_current_task
      @project.create_activity :upload_final_manuscript, owner: current_user,
                                parameters: { text: 'Uploaded Final Manuscript', form_data: params[:project].to_s}
      flash[:success] = 'Uploaded Final Manuscript'
      redirect_to @project
  	else
  		render 'show'
  	end
  end

  private
  def new_project_params
  	params.require(:project).permit(:title)
  end
  
  def update_project_params
  	params.require(:project).permit(:id, :final_title, :final_doc_file, :final_manuscript_pdf, 
  		:final_pdf, :stock_image_request_link, :layout_notes, :previously_published, :prev_publisher_and_date,
  		:stock_cover_image, :cover_concept_notes, :proofed_word_count, :cover_concept, :teamroom_link, :final_mobi,
  		:publication_date, :final_epub, :marketing_release_date, :paperback_cover_type, :age_range, :search_terms,
  		:bisac_code_3, :bisac_code_2, :bisac_code_1, :ebook_price, :print_price, :blurb_one_line, :endorsements,
  		:author_bio, :blurb_description, :final_title, :cover_art_approval_date, :alternative_cover_template,
  		:createspace_cover, :lightning_source_cover, :ebook_front_cover, :layout_approved_date, :layout_approved,
  		:layout_approval_issue_list, :final_page_count, :layout_upload, :page_header_display_name, :use_pen_name_on_title,
  		:use_pen_name_for_copyright, :exact_name_on_copyright, :pen_name, :special_text_treatment, :has_sub_chapters,
  		:layout_style_choice, :has_index, :non_standard_size, :has_internal_illustrations, :color_interior, :manuscript_edited,
  		:childrens_book, :manuscript_proofed, :edit_complete_date, :manuscript_original, :imprint_id, 
  		:genre_ids => [], :team_memberships_attributes => [:id, :role_id, :member_id, :percentage, :_destroy],
  		:price_change_promotions_attributes => [:type, :start_date, :price_promotion, :end_date, :price_after_promotion],
  		:status_updates_attributes => [:type, :status]
  		)
  end

  def update_control_number_params
    params.require(:control_number).permit(:id, :imprint, :ebook_library_price, :asin, :apple_id, :epub_isbn,
                                           :hardback_isbn, :paperback_isbn, :parse_id)
  end

  def set_project
  	@project = Project.find(params[:id])
  	rescue ActiveRecord::RecordNotFound
  		flash[:alert] = "The project you were looking for could not be found."
  		redirect_to projects_path
  end
  
  def update_current_task
  	current_task = @project.current_tasks.where(task_id: params[:submitted_task_id]).first
  	unless current_task.nil? || current_task.task.next_task.nil?
  		current_task.task_id = current_task.task.next_task.id
  		current_task.save
  	end
  end

  def reject_current_task
    current_task = @project.current_tasks.where(task_id: params[:submitted_task_id]).first
    unless current_task.nil? || current_task.task.rejected_task.nil?
      current_task.task_id = current_task.task.rejected_task.id
      current_task.save
    end
  end

  def team_memberships_params
    params.require(:team_membership).permit(:role_id, :member_id, :percentage)
  end
end
