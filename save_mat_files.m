clear;
companies = {'GOOGL','AAPL','FB'};
years = [2010,2011,2012,2013,2014];

%companies = {'GOOGL'};
%years = [2014];
scale = 5000;

for idx=companies
    for year=years
        company = idx{1};
        
        lambda        = 200;
        hazard_func  = @(r) constant_hazard(r, lambda);

        mu0    = 0;
        kappa0 = 1;
        alpha0 = 1;
        beta0  = 1;

        start_date = sprintf('01-jan-%s', num2str(year));
        end_date = sprintf('31-dec-%s', num2str(year));

        d1 = get_gf_histdata(company, 'start', start_date, 'end', end_date);

        X = fliplr(d1.open');
        X = X(1:end);
        
        if isnan(X(1))
            X = X(2:end);
        end
        
        [n, T] = size(X);

        % Plot the data and we'll have a look.
        subplot(2,1,1);
        %plot([1:T]', X, 'b-');
        grid;

        % Now we have some data in X and it's time to perform inference.
        % First, setup the matrix that will hold our beliefs about the current
        % run lengths.  We'll initialize it all to zero at first.  Obviously
        % we're assuming here that we know how long we're going to do the
        % inference.  You can imagine other data structures that don't make that
        % assumption (e.g. linked lists).  We're doing this because it's easy.
        R = zeros([T+1 T]);

        % At time t=1, we actually have complete knowledge about the run
        % length.  It is definitely zero.  See the paper for other possible
        % boundary conditions.
        R(1,1) = 1;

        % Track the current set of parameters.  These start out at the prior and
        % accumulate data as we proceed.
        muT    = mu0;
        kappaT = kappa0;
        alphaT = alpha0;
        betaT  = beta0;

        % Keep track of the maximums.
        maxes  = zeros([T+1]);

        % Loop over the data like we're seeing it all for the first time.
        for t=1:T

          % Evaluate the predictive distribution for the new datum under each of
          % the parameters.  This is the standard thing from Bayesian inference.
          predprobs = studentpdf(X(t), muT, ...
                                 betaT.*(kappaT+1)./(alphaT.*kappaT)/scale, ...
                                 2 * alphaT);

          % Evaluate the hazard function for this interval.
          H = hazard_func([1:t]');

          % Evaluate the growth probabilities - shift the probabilities down and to
          % the right, scaled by the hazard function and the predictive
          % probabilities.
          R(2:t+1,t+1) = R(1:t,t) .* predprobs .* (1-H);

          % Evaluate the probability that there *was* a changepoint and we're
          % accumulating the mass back down at r = 0.
          R(1,t+1) = sum( R(1:t,t) .* predprobs .* H );

          % Renormalize the run length probabilities for improved numerical
          % stability.
          R(:,t+1) = R(:,t+1) ./ sum(R(:,t+1));

          % Update the parameter sets for each possible run length.
          muT0    = [ mu0    ; (kappaT.*muT + X(t)) ./ (kappaT+1) ];
          kappaT0 = [ kappa0 ; kappaT + 1 ];
          alphaT0 = [ alpha0 ; alphaT + 0.5 ];
          betaT0  = [ beta0  ; betaT + (kappaT .*(X(t)-muT).^2)./(2*(kappaT+1)) ];
          muT     = muT0;
          kappaT  = kappaT0;
          alphaT  = alphaT0;
          betaT   = betaT0;

          % Store the maximum, to plot later.
          maxes(t) = find(R(:,t)==max(R(:,t)));

        end

        % Show the log smears and the maximums.
        subplot(1,1,1);
        hold off;
        plot(NaN);

        colormap(gray());
        imagesc(-log(R));
        hold on;

        [ax,p1,p2] = plotyy([1:T+1], maxes, [1:T], X, 'semilogy', 'plot');
        set(p1,'Color','r');

        %ylabel(ax(1), strcat('Lambda : ', int2str(lambda))); % label left y-axis

        for point=2:T
            if maxes(point-1) > maxes(point)
                hold(ax(2), 'on'); 
                plot(ax(2), point-1, X(point-1), 'O',...
                    'MarkerEdgeColor','k',...
                    'MarkerFaceColor','w',...
                    'MarkerSize',5);
            end
        end
        file_name = sprintf('%s-%s.mat', company, num2str(year));
        disp(file_name)
        
        save(file_name, 'maxes', 'R', 'X');
    end
end


% Use exportfig to save the image.  You might not have this installed.
if 0
  exportfig(gcf, 'gaussdemo.png', ...
            'Format',     'png', ...
            'Width',      8,   ...
            'Height',     8,   ...
            'FontMode',   'fixed', ...
            'FontSize',   10, ...
            'LineMode',   'fixed', ...
            'LineWidth',  0.5, ...
            'Color',      'rgb', ...
            'Bounds',     'loose');
end