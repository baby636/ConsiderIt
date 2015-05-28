require './shared'
require './customizations'
require './dock'
require './histogram'
require './permissions'
require './watch_star'
require './browser_hacks' # for access to browser object
require './browser_location' # for loadPage
require './bubblemouth'


window.Homepage = ReactiveComponent
  displayName: 'Homepage'
  render: ->
    doc = fetch('document')
    subdomain = fetch('subdomain')

    title = subdomain.app_title || subdomain.name
    if doc.title != title
      doc.title = title
      save doc

    customization('Homepage')()


#############
# SimpleHomepage
#
# Two column layout, with proposal name and mini histogram. 
# Divided into clusters. 

proposal_support = (proposal) ->
  opinions = fetch('/page/' + proposal.slug).opinions

  if not opinions
    return null
  sum = 0
  for o in opinions
    sum += customization("opinion_value", proposal)(o)
  return sum

window.proposal_editor = (proposal) ->
  editors = (e for e in proposal.roles.editor when e != '*')
  editor = editors.length > 0 and editors[0]

  return editor != '-' and editor


window.sorted_proposals = (cluster) ->
  cluster_key = "cluster/#{cluster.name}"
  show_icon = customization('show_proposer_icon', cluster_key)
  _.clone(cluster.proposals).sort (a,b) ->
    x_a = proposal_support(a) + (if show_icon \
                                  and proposal_editor(a) then 1 else 0)
    x_b = proposal_support(b) + (if show_icon \
                                  and proposal_editor(b) then 1 else 0)
    return x_b - x_a


cluster_styles = ->
  first_column =
    width: if !customization('lefty') then 480 else 350
    marginLeft: if customization('lefty') then 200
    display: 'inline-block'
    verticalAlign: 'top'
    position: 'relative'

  secnd_column =
    width: 300
    display: 'inline-block'
    verticalAlign: 'top'
    marginLeft: 50

  first_header =
    fontSize: 36
    marginBottom: 40
    fontWeight: 600
  _.extend(first_header, first_column)

  secnd_header =
    fontSize: 36
    marginBottom: 45
    fontWeight: 600
    position: 'relative'
    whiteSpace: 'nowrap'
  _.extend(secnd_header, secnd_column)

  [first_column, secnd_column, first_header, secnd_header]



window.SimpleHomepage = ReactiveComponent
  displayName: 'SimpleHomepage'

  render : ->
    subdomain = fetch('/subdomain')
    proposals = fetch('/proposals')
    current_user = fetch('/current_user')

    line_height = '1.8em'

    DIV
      className: 'simplehomepage'
      style: 
        fontSize: 22
        margin: if !customization('lefty') then 'auto'
        width: if !customization('lefty') then SIMPLEHOMEPAGEWIDTH
        marginTop: 10
        position: 'relative'

      STYLE null,
        '''a.proposal:hover {border-bottom: 1px solid grey}'''


      if current_user.logged_in
        @drawWatchFilter()

      # List all clusters
      for cluster, index in proposals.clusters or []
        cluster_key = "cluster/#{cluster.name}"

        options =   
          archived: customization("archived", cluster_key)
          label: customization("label", cluster_key)
          description: customization("description", cluster_key)
          homie_histo_title: customization("homie_histo_title", cluster_key)
          show_proposer_icon: customization("show_proposer_icon", cluster_key)

        if options.archived && (!@local.show_cluster || !(cluster.name in @local.show_cluster))
          DIV
            style: margin: "45px 0 45px #{if customization('lefty') then '200px' else '0'}"

            "#{options.label} "

            A 
              style: 
                textDecoration: 'underline'
              onClick: do(cluster) => => 
                @local.show_cluster ||= []
                @local.show_cluster.push(cluster.name)
                save(@local)
              'Show archive'
        else if cluster.proposals?.length > 0
          @drawCluster cluster, options

  typeset : -> 
    subdomain = fetch('/subdomain')
    if subdomain.name == 'RANDOM2015' && $('.MathJax').length == 0
      MathJax.Hub.Queue(["Typeset",MathJax.Hub,".proposal_homepage_name"])

  componentDidMount : -> @typeset()
  componentDidUpdate : -> @typeset()

  # cluster of proposals
  drawCluster: (cluster, options) -> 
    current_user = fetch '/current_user'

    DIV
      key: cluster.name
      id: if cluster.name && cluster.name then cluster.name.toLowerCase()
      style: margin: '45px 0'

      @drawClusterHeading cluster, options

      for proposal in sorted_proposals(cluster)
        @drawProposal proposal, options.show_proposer_icon

  drawClusterHeading : (cluster, options) -> 
    [first_column, secnd_column, first_header, secnd_header] = cluster_styles()

    cluster_key = "cluster/#{cluster.name}"

    DIV null,
      if options.label
        DIV 
          style: 
            width: 700
            marginLeft: if customization('lefty') then 200
          H1
            style: 
              fontSize: 48
              fontWeight: 200
              
            options.label

          if options.description
            DIV                
              style:
                fontSize: 22
                fontWeight: 200
                marginBottom: 10
                width: 700

              options.description

      # Header of cluster
      H1
        style: first_header
        cluster.name || 'Proposals'

        if cluster.proposals.length > 5
          " (#{cluster.proposals.length})"
      H1
        style: secnd_header
        SPAN
          style:
            position: 'absolute'
            bottom: -43
            fontSize: 21
            color: '#444'
            fontWeight: 300
          customization("slider_pole_labels.individual.oppose", cluster_key)
        SPAN
          style:
            position: 'absolute'
            bottom: -43
            fontSize: 21
            color: '#444'
            right: 0
            fontWeight: 300
          customization("slider_pole_labels.individual.support", cluster_key)
        SPAN 
          style: 
            position: 'relative'
            marginLeft: -(widthWhenRendered(options.homie_histo_title, 
                         {fontSize: 36, fontWeight: 600}) - secnd_column.width)/2
          options.homie_histo_title

  drawProposal : (proposal, icons) ->
    current_user = fetch '/current_user'

    watching = current_user.subscriptions[proposal.key] == 'watched'

    return if !watching && fetch('homepage_filter').watched

    [first_column, secnd_column, first_header, secnd_header] = cluster_styles()

    unread = hasUnreadNotifications(proposal)

    DIV
      key: proposal.key
      style:
        minHeight: 70

      DIV style: first_column,


        if current_user?.logged_in && unread
          A
            title: 'New activity'
            href: proposal_url(proposal)
            style: 
              position: 'absolute'
              left: -75
              top: 5
              width: 22
              height: 22
              textAlign: 'center'
              display: 'inline-block'
              cursor: 'pointer'
              backgroundColor: logo_red
              color: 'white'
              fontSize: 14
              borderRadius: '50%'
              padding: 2
              fontWeight: 600

            I 
              className: 'fa-bell fa'


        if current_user?.logged_in
          # ability to watch proposal
          
          WatchStar
            proposal: proposal
            size: 30
            style: 
              position: 'absolute'
              left: -40
              top: 5


        if icons
          editor = proposal_editor(proposal)

          # Person's icon
          A
            href: proposal_url(proposal)
            Avatar
              key: editor
              user: editor
              style:
                height: 50
                width: 50
                borderRadius: 0
                backgroundColor: '#ddd'

        # Name of Proposal
        DIV
          style:
            display: 'inline-block'
            fontWeight: 400
            marginLeft: if icons then 18
            paddingBottom: 20
            width: first_column.width - 50 + (if icons then -18 else 0)
            marginTop: if icons then 0 #9
          A
            className: 'proposal proposal_homepage_name'
            style: if not icons then {borderBottom: '1px solid grey'}
            href: proposal_url(proposal)
            proposal.name

      # Histogram for Proposal
      A
        href: proposal_url(proposal)
        DIV
          style: secnd_column
          Histogram
            key: "histogram-#{proposal.slug}"
            proposal: proposal
            opinions: opinionsForProposal(proposal)
            width: 300
            height: 50
            enable_selection: false
            draw_base: true    

  drawWatchFilter: -> 
    filter = fetch 'homepage_filter'

    DIV 
      id: 'watching_filter'
      style: 
        position: 'absolute'
        left: if customization('lefty') then 112 else -87  
        top: 5
        border: "1px solid #bbb"
        opacity: if !filter.watched && !@local.hover_watch_filter then .3
        padding: '3px 10px'
        cursor: 'pointer'
        display: 'inline-block'
        backgroundColor: '#fafafa'
        borderRadius: 8

      onMouseEnter: => 
        @local.hover_watch_filter = true

        tooltip = fetch 'tooltip'
        tooltip.coords = $(@getDOMNode()).find('#watching_filter').offset()
        tooltip.tip = "Filter proposals to those you're watching"
        save tooltip
        save @local

      onMouseLeave: => 
        @local.hover_watch_filter = false
        save @local
        tooltip = fetch 'tooltip'
        tooltip.coords = null
        save tooltip

      onClick: => 
        filter.watched = !filter.watched
        save filter

      SPAN
        style: 
          fontSize: 16
          verticalAlign: 'text-bottom'
          color: '#666'
        "only "

      I 
        className: "fa fa-star"
        style: 
          color: logo_red
          verticalAlign: 'text-bottom'

          # width: 30
          # height: 30


####
# LearnDecideShareHomepage
#
# A homepage where proposals are shown in a four column
# table.
#
# Proposals are divided into clusters. 
# 
# Customizations:
#
#  homepage_heading_columns
#    The labels of the four columns

window.LearnDecideShareHomepage = ReactiveComponent
  displayName: 'Homepage'

  render : ->
    subdomain = fetch('/subdomain')
    proposals = fetch('/proposals')

    homepage = fetch('/page/')
    
    # The "Welcome to the community!" people
    contributors = homepage.contributors.filter((u)-> !!fetch(u).avatar_file_name)
    contributors_without_avatar_count = homepage.contributors.filter((u)-> !fetch(u).avatar_file_name).length

    # Columns of the docking header for the proposal list.
    columns = customization('homepage_heading_columns') or [ 
                  {heading: 'Question', details: 'about the issues'}, \
                  {heading: 'Decide', details: 'what you think'}, \
                  {heading: 'Share', details: 'your opinion'}, \
                  {heading: 'Join', details: 'the contributors'}]

    docking_header_height = 79

    DIV 
      className: 'homepage'

      # Dock
      #   container_selector: '.homepage'
      #   dock_on_zoomed_screens: false
      #   parent_key: @local.key

      DIV 
        style: 
          backgroundColor: subdomain.branding.primary_color
          color: 'white'
          height: if subdomain.name != 'allsides' then docking_header_height
          minWidth: PAGE_WIDTH #minwidth is for when docking, position fixed mode

        TABLE 
          style: 
            margin: 'auto'
            paddingLeft: if subdomain.name != 'allsides' then 242

          TBODY null,
            TR null,
              for col in columns
                if col.heading
                  TD 
                    style: 
                      display: 'inline-block'
                      width: if subdomain.name != 'allsides' then 250 else 350

                    DIV 
                      style: 
                        fontWeight: 700
                        fontSize: 42
                        textAlign: 'center'

                      col.heading

                    if col.details
                      DIV 
                        style: 
                          fontWeight: 300
                          fontSize: 18
                          textAlign: 'center'
                          position: 'relative'
                          top: -8
                        col.details

      DIV style: {marginTop: 30},
        if contributors.length > 0
          DIV 
            style: 
              width: PAGE_WIDTH
              position: 'relative'
              margin: 'auto'
            DIV 
              style:
                left: if subdomain.name != 'allsides' then 1005 else 900
                position: 'absolute'
                width: 165
                textAlign: 'left'
                zIndex: 1

              for user in _(contributors).first(90)
                Avatar key: user, className: 'welcome_avatar', style: {height: 32, width: 32, margin: 1}
              if contributors_without_avatar_count > 0
                others = if contributors_without_avatar_count != 1 then 'others' else 'other'
                DIV style: {fontSize: 14, color: "#666"}, "...and #{contributors_without_avatar_count} #{others}"

        # Draw the proposal summaries
        for cluster, index in proposals.clusters or []
          description = customization "description", "cluster/#{cluster.name}"
          DIV null,
            if index == 1 and subdomain.name == 'livingvotersguide'
              customization('ZipcodeBox')()

            if cluster.proposals?.length > 0 
              TABLE
                style:
                  borderLeft: '0px solid rgb(191, 192, 194)'
                  margin: '20px auto'
                  position: 'relative'

                TBODY null,
                  TR null,
                    # Draw the cluster name off to the side
                    TH 
                      style: 
                        textAlign: 'right'
                        width: 115
                        padding: '8px 8px 8px 8px'
                        display: 'inline-block'
                        fontSize: 18
                        position: 'absolute'
                        left: -125
                        fontWeight: if browser.high_density_display then 300 else 400
                      cluster.name                

                  # Draw each proposal summary
                  for proposal in cluster.proposals
                    ProposalSummary
                      key: proposal.key
                      cluster: cluster.name
                      columns: columns
            
            # Cluster description
            if description 
              DIV
                style:
                  color: 'rgb(108,107,98)'
                  paddingLeft: 164
                  paddingTop: 12
                  margin: 'auto'
                  width: PAGE_WIDTH
                description

      if permit('create proposal') > 0
        # lazily styled & positioned...
        DIV style: {width: 871, margin: 'auto'}, 
          A 
            style: {color: '#888', textDecoration: 'underline', fontSize: 18, marginLeft: 30}
            href: '/proposal/new'
            'Create new proposal'

# Used by the LearnDecideShare homepage
window.ProposalSummary = ReactiveComponent
  displayName: 'ProposalSummary'

  render : ->
    subdomain = fetch('/subdomain')

    proposal = @data()
    your_opinion = fetch(proposal.your_opinion)
    
    hover_class = if @local.hovering_on == proposal.id then 'hovering' else ''

    link_hover_color = focus_blue
    cell_border = "1px solid #{if @local.hovering_on then link_hover_color else 'rgb(191, 192, 194)'}"
    TR 
      className: "proposal_summary " + hover_class
      style:
        height: ''
        padding: '0 30px'
        display: 'block'
        borderLeft: cell_border
        minHeight: 60
      onMouseEnter: => @local.hovering_on = true; save(@local)
      onMouseLeave: => @local.hovering_on = false; save(@local)

      if @props.columns[0].heading
        TD 
          className: 'summary_name'
          style: 
            width: 320
            display: 'inline-block'
            fontSize: 18
            fontWeight: 500
            marginRight: if subdomain.name == 'allsides' then 20

          A 
            href: proposal_url(proposal)
            style: 
              color: "#{if @local.hovering_on then link_hover_color else ''}" 
              borderBottom: '1px solid #b1afa7'

            if subdomain.name == 'livingvotersguide' && proposal.category 
              "#{proposal.category[0]}-#{proposal.designator}: "
            proposal.name

          if !proposal.active
            DIV
              style: 
                fontSize: 14
                color: '#414141'
                fontWeight: 200
                marginBottom: 15

              'closed'


      if @props.columns[1].heading

        TD
          style: 
            borderLeft: cell_border
            borderRight: cell_border
            cursor: 'pointer'
            width: 170
            textAlign: 'center'
            display: 'inline-block'
            height: '100%'
            minHeight: 66

          onClick: => loadPage "/#{proposal.slug}"
          if !proposal.your_opinion || !your_opinion.published \
             || isNeutralOpinion(your_opinion.stance)
            style = {fontWeight: 400, color: 'rgb(158,158,158)', fontSize: 21}
            if @local.hovering_on
              style.color = 'black'
              style.fontWeight = 600
            SPAN style: style, '?'
          else if your_opinion.stance < 0 && !isNeutralOpinion(your_opinion.stance)
            SPAN style: {position: 'relative', left: 14},
              IMG 
                className: 'summary_opinion_marker'
                src: asset('no_x.svg')
                style: {width: 24, position: 'absolute', left: -28}
              SPAN style: {color: 'rgb(239,95,98)', fontSize: 18, fontWeight: 600}, 'No'
          else
            SPAN style: {position: 'relative', left: 14},
              IMG 
                className: 'summary_opinion_marker'
                src: asset('yes_check.svg')
                style: {width: 24, position: 'absolute', left: -28}

              SPAN style: {color: 'rgb(166,204,70)', fontSize: 18, fontWeight: 600}, 'Yes'

      if @props.columns[2].heading

        TD
          className: 'summary_share'
          style: 
            cursor: 'pointer'
            width: 320
            display: 'inline-block'
            paddingLeft: 15
            marginTop: -4

          onClick: => loadPage proposal_url(proposal)
          if proposal.top_point
            mouth_style = 
              top: 5
              position: 'absolute'
              right: -COMMUNITY_POINT_MOUTH_WIDTH + 4
              transform: 'rotate(90deg)'

            DIV 
              className: 'top_point community_point pro'
              style : { width: 270, position: 'relative' }

              DIV className:'point_content',

                DIV 
                  key: 'community_point_mouth'
                  style: css.crossbrowserify mouth_style

                  Bubblemouth 
                    apex_xfrac: 0
                    width: COMMUNITY_POINT_MOUTH_WIDTH
                    height: COMMUNITY_POINT_MOUTH_WIDTH
                    fill: "#f6f7f9", 
                    stroke: 'transparent', 
                    stroke_width: 0
                    box_shadow:
                      dx: '3'
                      dy: '0'
                      stdDeviation: "2"
                      opacity: .5



                DIV className:'point_nutshell', style: {fontSize: 15},
                  "#{proposal.top_point.nutshell[0..30]}..."

