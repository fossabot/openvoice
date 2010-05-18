class VoicemailsController < ApplicationController
  before_filter :require_user, :only => [:index, :show, :new, :edit, :update, :destroy]
  
  def index
    @voicemails = current_user.voicemails.reverse

    respond_to do |format|
      format.html
      format.xml  { render :xml => @voicemails }
      format.json  { render :json => @voicemails }
    end
  end

  def show
    @voicemail = Voicemail.find(params[:id])

    respond_to do |format|
      format.html
      format.xml  { render :xml => @voicemail }
    end
  end

  def new
    @voicemail = Voicemail.new

    respond_to do |format|
      format.html
      format.xml  { render :xml => @voicemail }
    end
  end

  def create
    AWS::S3::Base.establish_connection!(
            :access_key_id     => 'AKIAJL7N4ODM3NMNTFCA',
            :secret_access_key => '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'
    )

    original_filename = params[:filename].original_filename

    AWS::S3::S3Object.store(original_filename,
                            params[:filename],
                            'voicemails-dev.tropovoice.com',
                            :access => :public_read)

    path = 'http://voicemails-dev.tropovoice.com' + '.s3.amazonaws.com/' + original_filename

    # TODO locate user via caller_id
    @voicemail = Voicemail.new(:filename => path,
                               :user_id => params[:user_id],
                               :from => params[:caller_id],
                               :text => "",
                               :transcription_id => params[:transcription_id])
    if @voicemail.save
      flash[:notice] = 'Voicemail was successfully created.'
    end
                                                    
    head 200
  end

  def update
    @voicemail = Voicemail.find(params[:id])

    respond_to do |format|
      if @voicemail.update_attributes(params[:voicemail])
        flash[:notice] = 'Voicemail was successfully updated.'
        format.html { redirect_to(@voicemail) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @voicemail.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    @voicemail = Voicemail.find(params[:id])
    @voicemail.destroy

    respond_to do |format|
      format.html { redirect_to(voicemails_url) }
      format.xml  { head :ok }
    end
  end

  def set_transcription
    # let the ugliness begin until tropo changes the mal-formed return of transcription results
    result_to_parse = params["<?xml version"]
    transcription_id = %r{(.*<identifier>)(.*)(</identifier>.*)}.match(result_to_parse)[2]
    transcription = %r{(.*<transcription>)(.*)(</transcription>.*)}.match(result_to_parse)[2]
    voicemail = Voicemail.find_by_transcription_id(transcription_id)
    voicemail.update_attribute("text", transcription)
    head 200
  end
end
